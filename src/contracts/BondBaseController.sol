// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IBondController, IBondController} from "../interfaces/IBondController.sol";
import {IBondDispatcher} from "../interfaces/IBondDispatcher.sol";
import {TransferHelper} from "../libraries/TransferHelper.sol";
import {FullMath} from "../libraries/FullMath.sol";

/// @title Bond Controller
/// @author Ekonomia: https://github.com/ekonomia-tech
/// @dev Handles bond pricing and debt maintenance
abstract contract BondBaseController is IBondController, Ownable {
    using TransferHelper for ERC20;
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
    uint48 internal constant FEE_DECIMALS = 10**5; // 1% = 1000

    // note: BondDispatcher handles interactions with users and issues tokens
    IBondDispatcher public immutable bondDispatcher;

    // controller - can change this, basically another authorized address
    address public controllerAddress;
    address public phoAddress;
    address public tonAddress;

    modifier onlyOwnerOrController() {
        require(
            msg.sender == owner() || msg.sender == controllerAddress,
            "BondController: not the owner or controller"
        );
        _;
    }

    modifier onlyBondDispatcher() {
        require(
            msg.sender == address(bondDispatcher),
            "BondController: not bond dispatcher"
        );
        _;
    }

    /// Constructor
    constructor(
        address _bondDispatcher,
        address _controllerAddress,
        address _phoAddress,
        address _tonAddress
    ) {
        require(
            address(_bondDispatcher) != address(0) &&
                address(_controllerAddress) != address(0) &&
                address(_phoAddress) != address(0) &&
                address(_tonAddress) != address(0),
            "BondController: zero address detected"
        );
        bondDispatcher = IBondDispatcher(_bondDispatcher);
        controllerAddress = _controllerAddress;
        phoAddress = _phoAddress;
        tonAddress = _tonAddress;
        defaultTuneInterval = 24 hours;
        defaultTuneAdjustment = 1 hours;
        minDebtDecayInterval = 3 days;
        minDepositInterval = 1 hours;
        minMarketDuration = 1 days;
        minDebtBuffer = 10000; // 10%
    }

    /// Market functions

    /// @inheritdoc IBondController
    function createMarket(bytes calldata params_)
        external
        virtual
        returns (uint256);

    /// @notice core market creation logic, see IBondController.createMarket()
    function _createMarket(MarketParams memory params_)
        internal
        onlyOwnerOrController
        returns (uint256)
    {
        // require payoutToken is either PHO or TON
        require(
            address(params_.payoutToken) == phoAddress ||
                address(params_.payoutToken) == tonAddress,
            "BondController: payoutToken must be PHO or TON"
        );

        // ensure params are in bounds
        require(
            params_.quoteToken.decimals() == 18 &&
                params_.scaleAdjustment < 24 &&
                params_.formattedInitialPrice > params_.formattedMinimumPrice &&
                (params_.conclusion - block.timestamp) > minMarketDuration &&
                (params_.depositInterval > minDepositInterval),
            "BondController: createMarket invalid params"
        );

        // scale var for scaling price / debt / control variable
        // scaleAdjustment should = (payoutDecimals - quoteDecimals) - ((payoutPriceDecimals - quotePriceDecimals) / 2)
        uint256 scale;
        unchecked {
            scale = 10**uint8(36 + params_.scaleAdjustment);
        }

        // bond dispatcher registers market
        uint256 marketId = bondDispatcher.registerMarket(
            params_.payoutToken,
            params_.quoteToken
        );

        // Setting vars
        uint32 debtDecayInterval = minDebtDecayInterval;
        uint256 tuneIntervalCapacity = (params_.capacity *
            params_.depositInterval) /
            uint256(params_.conclusion - block.timestamp);
        uint256 lastTuneDebt = ((params_.capacity) *
            uint256(debtDecayInterval)) /
            uint256(params_.conclusion - block.timestamp);

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
        // uint256 capacity = params_.capacity;

        uint256 targetDebt = (params_.capacity * uint256(debtDecayInterval)) /
            (uint256(params_.conclusion - block.timestamp));

        // max payout = capacity / deposit interval, i.e. 1000 TOK of capacity / 10 days = 100 TOK max
        uint256 maxPayout = (params_.capacity *
            uint256(params_.depositInterval)) /
            uint256(params_.conclusion - block.timestamp);

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

        // max debt is circuit breaker - 3 decimal, 1000 = 1% above initial price
        // i.e. 10% buffer = initial debt * 1.1
        uint256 maxDebt = targetDebt +
            ((targetDebt * minDebtBuffer) / FEE_DECIMALS);

        // CV initially is set to initial price = desired initial price
        // P = CV * D / S i.e. price = control variable * debt / scale

        // Bond terms
        terms[marketId] = BondTerms({
            controlVariable: (params_.formattedInitialPrice * scale) /
                targetDebt,
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

    /// @inheritdoc IBondController
    function setIntervals(uint256 marketId, uint32[] calldata intervals_)
        external
        override
        onlyOwnerOrController
    {
        require(
            intervals_[0] != 0 &&
                intervals_[1] != 0 &&
                intervals_[2] != 0 &&
                intervals_[0] > intervals_[1] &&
                intervals_.length == 3,
            "BondController: setIntervals invalid params"
        );

        BondMetadata storage meta = metadata[marketId];
        // check that tuneInterval >= depositInterval && debtDecayInterval >= minDebtDecayInterval
        require(
            intervals_[0] >= meta.depositInterval &&
                intervals_[2] >= minDebtDecayInterval,
            "BondController: setIntervals invalid params"
        );

        BondMarket memory market = markets[marketId];

        // update intervals
        meta.tuneInterval = intervals_[0];
        meta.tuneIntervalCapacity =
            (market.capacity * uint256(intervals_[0])) /
            (uint256(terms[marketId].conclusion) - block.timestamp); // don't have a stored value for market duration, this will update tuneIntervalCapacity based on time remaining
        meta.tuneAdjustmentDelay = intervals_[1];
        meta.debtDecayInterval = intervals_[2];
    }

    /// @inheritdoc IBondController
    function setDefaults(uint32[] memory defaults_)
        external
        override
        onlyOwnerOrController
    {
        require(
            defaults_.length == 6,
            "BondController: setDefaults invalid params"
        );
        defaultTuneInterval = defaults_[0];
        defaultTuneAdjustment = defaults_[1];
        minDebtDecayInterval = defaults_[2];
        minDepositInterval = defaults_[3];
        minMarketDuration = defaults_[4];
        minDebtBuffer = defaults_[5];
    }

    /// @inheritdoc IBondController
    function closeMarket(uint256 marketId)
        external
        override
        onlyOwnerOrController
    {
        _close(marketId);
    }

    /// Dispatcher functions

    /// @inheritdoc IBondController
    function purchaseBond(
        uint256 marketId,
        uint256 amount_,
        uint256 minAmountOut_
    ) external override onlyBondDispatcher returns (uint256) {
        BondMarket storage market = markets[marketId];
        BondTerms memory term = terms[marketId];

        // Markets end at a defined timestamp
        uint48 currentTime = uint48(block.timestamp);
        require(
            currentTime < term.conclusion,
            "BondController: purchaseBond window passed"
        );

        (uint256 price, uint256 payout) = _decayAndGetPrice(
            marketId,
            amount_,
            uint48(block.timestamp)
        ); // debt and control variable decay over time

        // payout must be > than user inputted min and < maxPayout and capacity
        require(
            (payout > minAmountOut_ &&
                payout < market.maxPayout &&
                payout < market.capacity),
            "BondController: purchaseBond invalid params"
        );

        // capacity is decreased by the paid amount
        market.capacity -= payout;

        // incrementing total debt raises the price of the next bond
        market.totalDebt += payout + 1; // add 1 to satisfy price inequality

        // track quote tokens purchased and payout tokens sold
        market.purchased += amount_;
        market.sold += payout;

        // circuit breaker - close mkt if max debt is reached
        if (term.maxDebt < market.totalDebt) {
            _close(marketId);
        } else {
            // market continues, the control variable is tuned to hit targets on time
            _tune(marketId, currentTime, price);
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
    function _decayAndGetPrice(
        uint256 marketId,
        uint256 amount_,
        uint48 time_
    ) internal returns (uint256, uint256) {
        BondMarket memory market = markets[marketId];

        // TODO: adjustments and CV tuning

        // price cannot be lower than min
        uint256 marketPrice_ = _currentMarketPrice(marketId);
        uint256 minPrice = market.minPrice;
        if (marketPrice_ < minPrice) marketPrice_ = minPrice;

        // payout for the deposit = amount / price
        // TODO: modify this and change tests
        uint256 payout_ = amount_; // amount_.mulDiv(market.scale, marketPrice_);

        // TODO: modify metadata lastDecay via debtPerSecond

        return (marketPrice_, payout_);
    }

    /// @notice auto-adjust control variable to hit capacity/spend target
    /// @param marketId id of market
    /// @param time_ timestamp (saves gas when passed in)
    /// @param price_ current price of the market
    function _tune(
        uint256 marketId,
        uint48 time_,
        uint256 price_
    ) internal {
        BondMetadata memory meta = metadata[marketId];
        BondMarket memory market = markets[marketId];

        // empty for now
    }

    /// Internal view functions

    /// @notice calculate current market price of payout token in quote tokens
    /// @dev see marketPrice() in IBondController for explanation of price computation
    /// @dev uses info from storage because data has been updated before call (vs marketPrice())
    /// @param marketId id of market
    /// @return price for market in payout token decimals
    function _currentMarketPrice(uint256 marketId)
        internal
        view
        returns (uint256)
    {
        BondMarket memory market = markets[marketId];
        return
            terms[marketId].controlVariable.mulDiv(
                market.totalDebt,
                market.scale
            );
    }

    /// @notice amount of debt to decay from total debt for market ID
    /// @param marketId id of market
    /// @return amount of debt to decay
    function _debtDecay(uint256 marketId) internal view returns (uint256) {
        BondMetadata memory meta = metadata[marketId];
        uint256 lastDecay = uint256(meta.lastDecay);
        uint256 currentTime = block.timestamp;
        uint256 secondsSince;
        unchecked {
            secondsSince = currentTime > lastDecay
                ? currentTime - lastDecay
                : 0;
        }
        return
            secondsSince > meta.debtDecayInterval
                ? markets[marketId].totalDebt
                : markets[marketId].totalDebt.mulDiv(
                    secondsSince,
                    uint256(meta.debtDecayInterval)
                );
    }

    /// @notice amount to decay control variable by
    /// @param marketId id of market
    /// @return decay change in control variable
    /// @return secondsSince seconds since last change in control variable
    /// @return active whether or not change remains active
    function _controlDecay(uint256 marketId)
        internal
        view
        returns (
            uint256,
            uint48,
            bool
        )
    {
        Adjustment memory info = adjustments[marketId];
        if (!info.active) return (0, 0, false);

        uint48 secondsSince = uint48(block.timestamp) - info.lastAdjustment;
        bool active = secondsSince < info.timeToAdjusted;
        uint256 decay = active
            ? info.change.mulDiv(
                uint256(secondsSince),
                uint256(info.timeToAdjusted)
            )
            : info.change;
        return (decay, secondsSince, active);
    }

    /// External view functions

    /// @inheritdoc IBondController
    function getMarketInfoForPurchase(uint256 marketId)
        external
        view
        returns (
            ERC20,
            ERC20,
            uint48,
            uint256
        )
    {
        BondMarket memory market = markets[marketId];
        return (
            market.payoutToken,
            market.quoteToken,
            terms[marketId].vesting,
            market.maxPayout
        );
    }

    /// @inheritdoc IBondController
    function marketPrice(uint256 marketId)
        public
        view
        override
        returns (uint256)
    {
        uint256 price = currentControlVariable(marketId).mulDivUp(
            currentDebt(marketId),
            markets[marketId].scale
        );

        return
            (price > markets[marketId].minPrice)
                ? price
                : markets[marketId].minPrice;
    }

    /// @inheritdoc IBondController
    function payoutFor(uint256 amount_, uint256 marketId)
        public
        view
        override
        returns (uint256)
    {
        // calc the payout for the given amount of tokens
        uint256 fee = amount_.mulDiv(bondDispatcher.getFee(), FEE_DECIMALS);
        uint256 payout = (amount_ - fee).mulDiv(
            markets[marketId].scale,
            marketPrice(marketId)
        );

        // check that the payout <= maxPayout
        require(
            payout < markets[marketId].maxPayout,
            "BondController: payoutFor exceeds maxPayout"
        );
        return payout;
    }

    /// @inheritdoc IBondController
    function maxAmountAccepted(uint256 marketId)
        external
        view
        returns (uint256)
    {
        // calc max amount of quote tokens for max bond size
        // max of maxPayout and remaining capacity converted to quote tokens
        BondMarket memory market = markets[marketId];
        uint256 price = marketPrice(marketId);
        uint256 quoteCapacity = market.capacity.mulDiv(price, market.scale);
        uint256 maxQuote = market.maxPayout.mulDiv(price, market.scale);
        uint256 amountAccepted = quoteCapacity < maxQuote
            ? quoteCapacity
            : maxQuote;

        // returns estimated fee based on amountAccepted and dispatcher fees (slightly conservative)
        uint256 estimatedFee = amountAccepted.mulDiv(
            bondDispatcher.getFee(),
            FEE_DECIMALS
        );

        return amountAccepted + estimatedFee;
    }

    /// @inheritdoc IBondController
    function currentDebt(uint256 marketId)
        public
        view
        override
        returns (uint256)
    {
        return markets[marketId].totalDebt - _debtDecay(marketId);
    }

    /// @inheritdoc IBondController
    function currentControlVariable(uint256 marketId)
        public
        view
        override
        returns (uint256)
    {
        (uint256 decay, , ) = _controlDecay(marketId);
        return terms[marketId].controlVariable - decay;
    }
}
