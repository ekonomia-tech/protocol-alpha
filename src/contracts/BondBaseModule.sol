// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IBondModule} from "../interfaces/IBondModule.sol";
import {FullMath} from "../libraries/FullMath.sol";

/// @title Bond Module
/// @author Ekonomia: https://github.com/ekonomia-tech
/// @dev Handles bonds
abstract contract BondBaseModule is IBondModule, Ownable {
    using SafeERC20 for ERC20;
    using FullMath for uint256;

    /// State vars
    mapping(uint256 => BondMarket) public markets; // main info for each bond market
    mapping(uint256 => BondTerms) public terms; // info to control how bond market changes
    mapping(uint256 => BondMetadata) public metadata; // data for tuning bond market
    mapping(uint256 => Adjustment) public adjustments; // control variable changes

    uint32 public defaultTuneInterval; // tune interval
    uint32 public defaultTuneAdjustment; // tune adjustment
    uint32 public minDebtDecayInterval; // decay
    uint32 public minDepositInterval; // deposit interval
    uint32 public minMarketDuration; // market duration
    uint32 public minDebtBuffer; // debt buffer

    // vesting param longer than 50 years is considered a timestamp for fixed expiry
    uint48 internal constant MAX_FIXED_TERM = 52 weeks * 50;
    uint48 internal constant FEE_DECIMALS = 10 ** 5; // 1% = 1000

    // controller - can change this, basically another authorized address
    address public controllerAddress;
    address public phoAddress;
    address public tonAddress;

    // Dispatcher vars
    uint48 public protocolFee; // fees paid to protocol, configureable by policy, must be > 30bps
    address internal immutable _protocol; // address protocol recieves fees at
    mapping(address => mapping(ERC20 => uint256)) public rewards; // fees earned by address per token
    uint256 public marketCounter; // counter of bond markets for controller
    mapping(address => uint256[]) public marketsForPayout; // market ids for payout token
    mapping(address => uint256[]) public marketsForQuote; // market ids for quote token

    modifier onlyOwnerOrController() {
        require(
            msg.sender == owner() || msg.sender == controllerAddress,
            "BondModule: not the owner or controller"
        );
        _;
    }

    /// Constructor
    constructor(
        address _controllerAddress,
        address _phoAddress,
        address _tonAddress,
        address protocol_
    ) {
        require(
            address(_controllerAddress) != address(0) && address(_phoAddress) != address(0)
                && address(_tonAddress) != address(0) && address(protocol_) != address(0),
            "BondModule: zero address detected"
        );
        controllerAddress = _controllerAddress;
        phoAddress = _phoAddress;
        tonAddress = _tonAddress;
        defaultTuneInterval = 24 hours;
        defaultTuneAdjustment = 1 hours;
        minDebtDecayInterval = 3 days;
        minDepositInterval = 1 hours;
        minMarketDuration = 1 days;
        minDebtBuffer = 10000; // 10%
        _protocol = protocol_;
        protocolFee = 0;
    }

    // TODO: implement IModule interface, i.e. mintPho(), burnPho(), etc.

    /// @inheritdoc IBondModule
    function setProtocolFee(uint48 fee_) external override onlyOwnerOrController {
        protocolFee = fee_;
    }

    /// Market functions

    /// @inheritdoc IBondModule
    function registerMarket(ERC20 payoutToken_, ERC20 quoteToken_)
        public
        override
        onlyOwnerOrController
        returns (uint256)
    {
        uint256 marketId = marketCounter;
        marketsForPayout[address(payoutToken_)].push(marketId);
        marketsForQuote[address(quoteToken_)].push(marketId);
        ++marketCounter;
        return marketId;
    }

    /// @inheritdoc IBondModule
    function claimFees(ERC20[] memory tokens_, address to_)
        external
        override
        onlyOwnerOrController
    {
        uint256 len = tokens_.length;
        for (uint256 i; i < len; ++i) {
            ERC20 token = tokens_[i];
            uint256 send = rewards[msg.sender][token];
            rewards[msg.sender][token] = 0;
            token.transfer(to_, send);
        }
    }

    /// @inheritdoc IBondModule
    function getFee() public view returns (uint48) {
        return protocolFee;
    }

    /// @inheritdoc IBondModule
    function createMarket(bytes calldata params_) external virtual returns (uint256);

    /// @notice core market creation logic, see IBondModule.createMarket()
    function _createMarket(MarketParams memory params_)
        internal
        onlyOwnerOrController
        returns (uint256)
    {
        require(
            address(params_.payoutToken) == phoAddress || address(params_.payoutToken) == tonAddress,
            "BondModule: payoutToken must be PHO or TON"
        ); // require payoutToken is either PHO or TON
        require(
            params_.quoteToken.decimals() == 18 && params_.scaleAdjustment < 24
                && params_.formattedInitialPrice > params_.formattedMinimumPrice
                && (params_.conclusion - block.timestamp) > minMarketDuration
                && (params_.depositInterval > minDepositInterval),
            "BondModule: createMarket invalid params"
        ); // ensure params are in bounds

        // scale var for scaling price / debt / control variable
        // scaleAdjustment should = (payoutDecimals - quoteDecimals) - ((payoutPriceDecimals - quotePriceDecimals) / 2)
        uint256 scale = 10 ** uint8(36 + params_.scaleAdjustment);

        // bond dispatcher registers market
        uint256 marketId = registerMarket(params_.payoutToken, params_.quoteToken);

        // Setting vars
        uint32 debtDecayInterval = minDebtDecayInterval;
        uint256 tuneIntervalCapacity = (params_.capacity * params_.depositInterval)
            / uint256(params_.conclusion - block.timestamp);
        uint256 lastTuneDebt = ((params_.capacity) * uint256(debtDecayInterval))
            / uint256(params_.conclusion - block.timestamp);

        // Bond metadata
        metadata[marketId] = BondMetadata({
            lastTune: uint48(block.timestamp),
            lastDecay: uint48(block.timestamp),
            length: uint32(params_.conclusion - block.timestamp),
            depositInterval: params_.depositInterval,
            tuneInterval: defaultTuneInterval,
            tuneAdjustmentDelay: defaultTuneAdjustment,
            debtDecayInterval: debtDecayInterval,
            tuneIntervalCapacity: tuneIntervalCapacity,
            tuneBelowCapacity: params_.capacity - tuneIntervalCapacity,
            lastTuneDebt: lastTuneDebt
        });

        // target debt = capacity * (debtDecayInterval)/(length of mkt) - assumes no ourchases made
        // Note the price must be specified as follows = (payoutPriceCoefficient / quotePriceCoefficient)
        //         * 10**(36 + scaleAdjustment + quoteDecimals - payoutDecimals + payoutPriceDecimals - quotePriceDecimals)

        uint256 targetDebt = (params_.capacity * uint256(debtDecayInterval))
            / (uint256(params_.conclusion - block.timestamp));

        // max payout = capacity / deposit interval, i.e. 1000 TOK of capacity / 10 days = 100 TOK max
        uint256 maxPayout = (params_.capacity * uint256(params_.depositInterval))
            / uint256(params_.conclusion - block.timestamp);

        // Bond market
        markets[marketId] = BondMarket({
            payoutToken: params_.payoutToken,
            quoteToken: params_.quoteToken,
            capacity: params_.capacity,
            totalDebt: targetDebt,
            minPrice: params_.formattedMinimumPrice,
            maxPayout: maxPayout,
            purchased: 0,
            sold: 0,
            scale: scale
        });

        // max debt circuit breaker - 3 decimal, 1000 = 1% above, 10000 = 10% = 1.1 * initial debt
        uint256 maxDebt = targetDebt + ((targetDebt * minDebtBuffer) / FEE_DECIMALS);

        // CV initially is set to initial price = desired initial price
        // P = CV * D / S i.e. price = control variable * debt / scale

        // Bond terms
        terms[marketId] = BondTerms({
            controlVariable: (params_.formattedInitialPrice * scale) / targetDebt,
            maxDebt: maxDebt,
            vesting: params_.vesting,
            conclusion: params_.conclusion
        });

        emit MarketCreated(
            marketId,
            address(params_.payoutToken),
            address(params_.quoteToken),
            params_.vesting,
            params_.formattedInitialPrice
            );
        return marketId;
    }

    /// @inheritdoc IBondModule
    function setIntervals(uint256 marketId, uint32[] calldata intervals_)
        external
        override
        onlyOwnerOrController
    {
        require(
            intervals_[0] != 0 && intervals_[1] != 0 && intervals_[2] != 0
                && intervals_[0] > intervals_[1] && intervals_.length == 3,
            "BondModule: setIntervals invalid params"
        );

        BondMetadata storage meta = metadata[marketId];
        require(
            intervals_[0] >= meta.depositInterval && intervals_[2] >= minDebtDecayInterval,
            "BondModule: setIntervals invalid params"
        ); // check tuneInterval >= depositInterval && debtDecayInterval >= minDebtDecayInterval

        // update intervals
        BondMarket memory market = markets[marketId];
        meta.tuneInterval = intervals_[0];
        meta.tuneIntervalCapacity = (market.capacity * uint256(intervals_[0]))
            / (uint256(terms[marketId].conclusion) - block.timestamp); // don't have a stored value for market duration, this will update tuneIntervalCapacity based on time remaining
        meta.tuneAdjustmentDelay = intervals_[1];
        meta.debtDecayInterval = intervals_[2];
    }

    /// @inheritdoc IBondModule
    function setDefaults(uint32[] memory defaults_) external override onlyOwnerOrController {
        require(defaults_.length == 6, "BondModule: setDefaults invalid params");
        defaultTuneInterval = defaults_[0];
        defaultTuneAdjustment = defaults_[1];
        minDebtDecayInterval = defaults_[2];
        minDepositInterval = defaults_[3];
        minMarketDuration = defaults_[4];
        minDebtBuffer = defaults_[5];
    }

    /// @inheritdoc IBondModule
    function closeMarket(uint256 marketId) external override onlyOwnerOrController {
        _close(marketId);
    }

    /// User functions

    /// @inheritdoc IBondModule
    function purchase(address recipient_, uint256 marketId, uint256 amount_, uint256 minAmountOut_)
        external
        virtual
        returns (uint256, uint48)
    {
        ERC20 payoutToken;
        ERC20 quoteToken;
        uint48 vesting;

        // calculate fees for purchase via protocol fee
        uint256 toProtocol = (amount_ * protocolFee) / FEE_DECIMALS;
        (payoutToken, quoteToken, vesting,) = getMarketInfoForPurchase(marketId);

        // bond controller handles bond pricing, capacity, and duration
        uint256 amountLessFee = amount_ - toProtocol;
        uint256 payout = purchaseBond(marketId, amountLessFee, minAmountOut_);

        // allocate fees to protocol
        rewards[_protocol][quoteToken] += toProtocol;
        // note: need to handle transfers and ensure enough payout tokens are available
        _handleTransfers(marketId, amount_, payout, toProtocol);
        // note: handle payout to user
        uint48 expiry = 0; // _handlePayout(recipient_, payout, payoutToken, vesting);

        emit Bonded(marketId, amount_, payout);
        return (payout, expiry);
    }

    /// @notice handles transfer of funds from user and bond controller
    function _handleTransfers(
        uint256 marketId,
        uint256 amount_,
        uint256 payout_,
        uint256 feePamarketId
    ) internal {}

    /// @notice handle payout to recipient - must be implemented by inheriting contract
    /// @param recipient_ recipient of payout
    /// @param payout_ payout
    /// @param underlying_ token to be paid out
    /// @param vesting_ time parameter depending on implementation
    /// @return expiry timestamp when the payout will vest
    function _handlePayout(address recipient_, uint256 payout_, ERC20 underlying_, uint48 vesting_)
        internal
        virtual
        returns (uint48);

    /// Dispatcher functions

    /// @inheritdoc IBondModule
    function purchaseBond(uint256 marketId, uint256 amount_, uint256 minAmountOut_)
        public
        override
        returns (uint256)
    {
        BondMarket storage market = markets[marketId];
        BondTerms memory term = terms[marketId];

        uint48 currentTime = uint48(block.timestamp);
        require(currentTime < term.conclusion, "BondModule: purchaseBond window passed"); // Markets end at a defined timestamp
        (uint256 price, uint256 payout) =
            _decayAndGetPrice(marketId, amount_, uint48(block.timestamp)); // debt and control variable decay over time
        require(
            (payout > minAmountOut_ && payout < market.maxPayout && payout < market.capacity),
            "BondModule: purchaseBond invalid params"
        ); // payout must be > than min and < maxPayout and capacity

        market.capacity -= payout; // decrease capacity by paid amount
        market.totalDebt += payout + 1; // add to total debt to raise price for next bond, +1 to satisfy price inequality
        market.purchased += amount_; // add to purchased
        market.sold += payout; // add to sold

        if (term.maxDebt < market.totalDebt) {
            _close(marketId); // close mkt if max debt reached
        } else {
            _tune(marketId, currentTime, price); // otherwise tune CV to hit targets
        }
        return payout;
    }

    /// Internal functions

    /// @notice close a market - sets capacity to 0 and stops bonding
    function _close(uint256 marketId) internal {
        terms[marketId].conclusion = uint48(block.timestamp);
        markets[marketId].capacity = 0;
        emit MarketClosed(marketId);
    }

    /// @notice decay debt, and adjust control variable if there is an active change
    /// @param marketId id of market
    /// @param amount_ amount of quote tokens being purchased
    /// @param time_ current timestamp (saves gas when passed in)
    /// @return marketPrice_ current market price of bond, accounting for decay
    /// @return payout_ amount of payout tokens received at current price
    function _decayAndGetPrice(uint256 marketId, uint256 amount_, uint48 time_)
        internal
        returns (uint256, uint256)
    {
        BondMarket memory market = markets[marketId];
        // note: need to add in adjustments and CV tuning
        // price cannot be lower than min
        uint256 marketPrice_ = _currentMarketPrice(marketId);
        uint256 minPrice = market.minPrice;
        if (marketPrice_ < minPrice) {
            marketPrice_ = minPrice;
        }

        // payout for the deposit = amount / price, note: need to modify this
        uint256 payout_ = amount_; // amount_.mulDiv(market.scale, marketPrice_);
        // note: need to modify metadata lastDecay via debtPerSecond
        return (marketPrice_, payout_);
    }

    /// @notice auto-adjust control variable to hit capacity/spend target
    /// @param marketId id of market
    /// @param time_ timestamp (saves gas when passed in)
    /// @param price_ current price of the market
    function _tune(uint256 marketId, uint48 time_, uint256 price_) internal {
        BondMetadata memory meta = metadata[marketId];
        BondMarket memory market = markets[marketId];
        // note: fill out
    }

    /// Internal view functions

    /// @notice calculate current market price of payout token in quote tokens
    /// @dev see marketPrice() in IBondModule for explanation of price computation
    /// @dev uses info from storage because data has been updated before call (vs marketPrice())
    /// @param marketId id of market
    /// @return price for market in payout token decimals
    function _currentMarketPrice(uint256 marketId) internal view returns (uint256) {
        BondMarket memory market = markets[marketId];
        return (terms[marketId].controlVariable * market.totalDebt) / market.scale;
    }

    /// @notice amount of debt to decay from total debt for market ID
    /// @param marketId id of market
    /// @return amount of debt to decay
    function _debtDecay(uint256 marketId) internal view returns (uint256) {
        BondMetadata memory meta = metadata[marketId];
        uint256 lastDecay = uint256(meta.lastDecay);
        uint256 currentTime = block.timestamp;
        uint256 secondsSince = currentTime > lastDecay ? currentTime - lastDecay : 0;
        return secondsSince > meta.debtDecayInterval
            ? markets[marketId].totalDebt
            : (markets[marketId].totalDebt * secondsSince) / uint256(meta.debtDecayInterval);
    }

    /// @notice amount to decay control variable by
    /// @param marketId id of market
    /// @return decay change in control variable
    /// @return secondsSince seconds since last change in control variable
    /// @return active whether or not change remains active
    function _controlDecay(uint256 marketId) internal view returns (uint256, uint48, bool) {
        Adjustment memory info = adjustments[marketId];
        if (!info.active) {
            return (0, 0, false);
        }

        uint48 secondsSince = uint48(block.timestamp) - info.lastAdjustment;
        bool active = secondsSince < info.timeToAdjusted;
        uint256 decay = active
            ? (info.change * uint256(secondsSince)) / uint256(info.timeToAdjusted)
            : info.change;
        return (decay, secondsSince, active);
    }

    /// External view functions

    /// @inheritdoc IBondModule
    function getMarketInfoForPurchase(uint256 marketId)
        public
        view
        returns (ERC20, ERC20, uint48, uint256)
    {
        BondMarket memory market = markets[marketId];
        return (market.payoutToken, market.quoteToken, terms[marketId].vesting, market.maxPayout);
    }

    /// @inheritdoc IBondModule
    function marketPrice(uint256 marketId) public view override returns (uint256) {
        uint256 price = currentControlVariable(marketId).mulDivUp(
            currentDebt(marketId), markets[marketId].scale
        );
        return (price > markets[marketId].minPrice) ? price : markets[marketId].minPrice;
    }

    /// @inheritdoc IBondModule
    function payoutFor(uint256 amount_, uint256 marketId) public view override returns (uint256) {
        // calc the payout for the given amount of tokens
        uint256 fee = amount_.mulDiv(getFee(), FEE_DECIMALS);
        uint256 payout = (amount_ - fee).mulDiv(markets[marketId].scale, marketPrice(marketId));
        require(payout < markets[marketId].maxPayout, "BondModule: payoutFor exceeds maxPayout"); //check that the payout <= maxPayout
        return payout;
    }

    /// @inheritdoc IBondModule
    function maxAmountAccepted(uint256 marketId) external view returns (uint256) {
        // calc max amount of quote tokens for max bond size
        BondMarket memory market = markets[marketId];
        uint256 price = marketPrice(marketId);
        uint256 quoteCapacity = market.capacity.mulDiv(price, market.scale);
        uint256 maxQuote = market.maxPayout.mulDiv(price, market.scale);
        uint256 amountAccepted = quoteCapacity < maxQuote ? quoteCapacity : maxQuote;
        // returns estimated fee based on amountAccepted and dispatcher fees (slightly conservative)
        uint256 estimatedFee = (amountAccepted * getFee()) / FEE_DECIMALS;
        return amountAccepted + estimatedFee;
    }

    /// @inheritdoc IBondModule
    function currentDebt(uint256 marketId) public view override returns (uint256) {
        return markets[marketId].totalDebt - _debtDecay(marketId);
    }

    /// @inheritdoc IBondModule
    function currentControlVariable(uint256 marketId) public view override returns (uint256) {
        (uint256 decay,,) = _controlDecay(marketId);
        return terms[marketId].controlVariable - decay;
    }
}
