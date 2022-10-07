// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IBondModule} from "../interfaces/IBondModule.sol";

/// @title Bond Module
/// @author Ekonomia: https://github.com/ekonomia-tech
/// @dev Handles bonds
abstract contract BondBaseModule is IBondModule, Ownable {
    using SafeERC20 for ERC20;

    /// Errors
    error FullBalanceNotRecieved();
    error ZeroAddressDetected();
    error PayoutTokenPHOorTON();
    error CreateMarketInvalidParams();
    error PurchaseWindowPassed();
    error PurchaseBondInvalidParams();
    error PayoutTooLarge();
    error CannotPriceAfterTermEnd();
    error AdjustedDiscountTooHigh();

    /// State vars
    mapping(uint256 => BondMarket) public markets; // main info for each bond market
    mapping(address => uint256[]) public marketsForPayout; // market ids for payout token
    mapping(address => uint256[]) public marketsForQuote; // market ids for quote token
    mapping(address => mapping(ERC20 => uint256)) public rewards; // fees earned by address per token
    address public controllerAddress; // authorized address
    address public phoAddress;
    address public tonAddress;
    uint256 public marketCounter; // counter of bond markets for controller
    uint256 public protocolFee; // fees paid to protocol, units of 10**6

    uint256 internal constant FEE_DECIMALS = 10 ** 6; // 1% = 1000
    address internal immutable _protocol; // address protocol recieves fees at

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
        if (
            address(_controllerAddress) == address(0) || address(_phoAddress) == address(0)
                || address(_tonAddress) == address(0) || address(protocol_) == address(0)
        ) {
            revert ZeroAddressDetected();
        }
        controllerAddress = _controllerAddress;
        phoAddress = _phoAddress;
        tonAddress = _tonAddress;
        _protocol = protocol_;
        protocolFee = 0;
    }

    /// @inheritdoc IBondModule
    function setProtocolFee(uint256 newProtocolFee) external override onlyOwnerOrController {
        protocolFee = newProtocolFee;
        emit ProtocolFeeSet(newProtocolFee);
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
    function createMarket(bytes calldata params) external virtual returns (uint256);

    /// @notice core market creation logic, see IBondModule.createMarket()
    function _createMarket(MarketParams memory params)
        internal
        onlyOwnerOrController
        returns (uint256)
    {
        if (address(params.payoutToken) != phoAddress && address(params.payoutToken) != tonAddress)
        {
            revert PayoutTokenPHOorTON();
        }

        if (params.termStart > params.termEnd) {
            revert CreateMarketInvalidParams();
        }

        // Market gets registered
        uint256 marketId = registerMarket(params.payoutToken, params.quoteToken);

        // Bond market
        markets[marketId] = BondMarket({
            payoutToken: params.payoutToken,
            quoteToken: params.quoteToken,
            capacity: params.capacity,
            initialPrice: params.initialPrice,
            maxDiscount: params.maxDiscount,
            termStart: params.termStart,
            termEnd: params.termEnd,
            totalDebt: 0,
            purchased: 0,
            sold: 0
        });

        emit MarketCreated(
            marketId,
            address(params.payoutToken),
            address(params.quoteToken),
            params.capacity,
            params.maxDiscount,
            params.initialPrice,
            params.termStart,
            params.termEnd
            );
        return marketId;
    }

    /// @inheritdoc IBondModule
    function closeMarket(uint256 marketId) external override onlyOwnerOrController {
        _close(marketId);
    }

    /// User functions

    /// @inheritdoc IBondModule
    function purchase(address recipient_, uint256 marketId, uint256 amount)
        external
        virtual
        returns (uint256, uint256)
    {
        ERC20 payoutToken;
        ERC20 quoteToken;
        uint256 termEnd;
        uint256 maxDiscount;

        // calculate fees for purchase via protocol fee
        uint256 toProtocol = (amount * protocolFee) / FEE_DECIMALS;
        (payoutToken, quoteToken, termEnd, maxDiscount) = getMarketInfoForPurchase(marketId);

        // bond controller handles bond pricing, capacity, and duration
        uint256 amountLessFee = amount - toProtocol;
        uint256 payout = purchaseBond(marketId, amountLessFee);

        // allocate fees to protocol
        rewards[_protocol][quoteToken] += toProtocol;
        _handleTransfers(marketId, amount, payout, toProtocol); // transfers
        _handlePayout(recipient_, payout, payoutToken, termEnd); // payout to user

        emit Bonded(marketId, amount, payout);
        return (payout, termEnd);
    }

    /// @notice handles transfer of funds from user
    function _handleTransfers(uint256 marketId, uint256 amount, uint256 payout, uint256 toProtocol)
        internal
    {
        ERC20 payoutToken;
        ERC20 quoteToken;
        uint256 termEnd;
        uint256 maxDiscount;
        (payoutToken, quoteToken, termEnd, maxDiscount) = getMarketInfoForPurchase(marketId);
        // User sends quoteToken worth amount
        uint256 quoteBalance = quoteToken.balanceOf(address(this));
        quoteToken.safeTransferFrom(msg.sender, address(this), amount);

        //
        uint256 payoutBalance = payoutToken.balanceOf(address(this));
        if (payoutBalance <= payout) {
            revert PayoutTooLarge();
        }

        //TODO: where do quote tokens go to?
        //quoteToken.safeTransfer(owner, amountLessFee);
    }

    /// @notice handle payout to recipient - must be implemented by inheriting contract
    /// @param recipient_ recipient of payout
    /// @param payout payout
    /// @param underlying_ token to be paid out
    /// @param termEnd time parameter depending on implementation
    /// @return expiry timestamp when the payout will vest
    function _handlePayout(address recipient_, uint256 payout, ERC20 underlying_, uint256 termEnd)
        internal
        virtual
        returns (uint256);

    /// Dispatcher functions

    /// @inheritdoc IBondModule
    function purchaseBond(uint256 marketId, uint256 amount) public override returns (uint256) {
        BondMarket storage market = markets[marketId];

        if (block.timestamp >= market.termEnd) {
            revert PurchaseWindowPassed();
        }

        uint256 payout = _getPrice(marketId, amount);

        if (payout > market.capacity) {
            revert PurchaseBondInvalidParams();
        }

        market.capacity -= payout; // decrease capacity by paid amount
        market.totalDebt += payout; // add to total debt to raise price for next bond, +1 to satisfy price inequality
        market.purchased += amount; // add to purchased
        market.sold += payout; // add to sold

        if (market.capacity == 0) {
            _close(marketId); // close mkt if max capacity reached
        }
        return payout;
    }

    /// Internal functions

    /// @notice close a market - sets capacity to 0 and stops bonding
    function _close(uint256 marketId) internal {
        markets[marketId].termEnd = block.timestamp;
        markets[marketId].capacity = 0;
        emit MarketClosed(marketId);
    }

    /// @notice calculates payout amount for given amount of deposit
    /// @param marketId id of market
    /// @param amount amount of deposited quote tokens
    /// @return payout amount of payout tokens to be recieved
    function _getPrice(uint256 marketId, uint256 amount) internal view returns (uint256) {
        BondMarket memory market = markets[marketId];
        if (block.timestamp > market.termEnd) {
            revert CannotPriceAfterTermEnd();
        }

        // market price is linear decay based on maxDiscount and time elapsed
        uint256 timeElapsed = market.termEnd - block.timestamp;
        uint256 duration = market.termEnd - market.termStart;
        uint256 adjustedDiscount = (market.maxDiscount * timeElapsed) / duration;
        if (adjustedDiscount >= 10 ** 6) {
            revert AdjustedDiscountTooHigh();
        }

        uint256 scale = (10 ** (18 - (market.quoteToken).decimals()));
        uint256 payout = (amount * (market.initialPrice * scale * (10 ** 6 + adjustedDiscount)))
            / (10 ** 6 * 10 ** 18);
        return payout;
    }

    /// External view functions

    /// @inheritdoc IBondModule
    function getMarketInfoForPurchase(uint256 marketId)
        public
        view
        returns (ERC20, ERC20, uint256, uint256)
    {
        BondMarket memory market = markets[marketId];
        return (market.payoutToken, market.quoteToken, market.termEnd, market.maxDiscount);
    }
}
