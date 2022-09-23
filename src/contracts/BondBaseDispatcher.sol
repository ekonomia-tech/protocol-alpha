// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IBondDispatcher} from "../interfaces/IBondDispatcher.sol";
import {IBondController} from "../interfaces/IBondController.sol";
import {TransferHelper} from "../libraries/TransferHelper.sol";
import {FullMath} from "../libraries/FullMath.sol";

/// @title Bond Dispatcher
/// @author Ekonomia: https://github.com/ekonomia-tech
/// @dev Handles user interactions with bonds
abstract contract BondBaseDispatcher is
    IBondDispatcher,
    Ownable,
    ReentrancyGuard
{
    using TransferHelper for ERC20;
    using FullMath for uint256;

    /// Errors
    error Dispatcher_NotAuthorized();
    error Dispatcher_TokenDoesNotExist(ERC20 underlying, uint48 expiry);
    error Dispatcher_UnsupportedToken();

    /// State vars
    uint48 public protocolFee; // fees paid to protocol, configureable by policy, must be > 30bps
    uint48 public createFeeDiscount; // fee discount for create function
    uint48 public constant FEE_DECIMALS = 1e5; // one percent equals 1000
    mapping(address => mapping(ERC20 => uint256)) public rewards; // fees earned by address per token
    address internal immutable _protocol; // address protocol recieves fees at
    address public controllerAddress; // controller - authorized address
    address public bondController; // bond controller

    uint256 public marketCounter; // counter of bond markets for controller
    mapping(address => uint256[]) public marketsForPayout; // market ids for payout token
    mapping(address => uint256[]) public marketsForQuote; // market ids for quote token

    modifier onlyOwnerOrController() {
        require(
            msg.sender == owner() ||
                msg.sender == controllerAddress ||
                "BondDispatcher: not the owner or controller"
        );
        _;
    }

    /// Constructor
    constructor(address protocol_, address _controllerAddress) {
        _protocol = protocol_;
        controllerAddress = _controllerAddress;
        protocolFee = 0;
    }

    /// @inheritdoc IBondDispatcher
    function setProtocolFee(uint48 fee_)
        external
        override
        onlyOwnerOrController
    {
        protocolFee = fee_;
    }

    /// @inheritdoc IBondDispatcher
    function setBondController(address _bondController)
        external
        override
        onlyOwnerOrController
    {
        bondController = _bondController;
    }

    /// @inheritdoc IBondDispatcher
    function registerMarket(ERC20 payoutToken_, ERC20 quoteToken_)
        external
        override
        onlyOwnerOrController
        returns (uint256)
    {
        marketId = marketCounter;
        marketsForPayout[address(payoutToken_)].push(marketId);
        marketsForQuote[address(quoteToken_)].push(marketId);
        ++marketCounter;
        return marketId;
    }

    /// @inheritdoc IBondDispatcher
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
            token.safeTransfer(to_, send);
        }
    }

    /// @inheritdoc IBondDispatcher
    function getFee() external view returns (uint48) {
        return protocolFee;
    }

    /// User functions

    /// @inheritdoc IBondDispatcher
    function purchase(
        address recipient_,
        uint256 marketId,
        uint256 amount_,
        uint256 minAmountOut_
    ) external virtual nonReentrant returns (uint256, uint48) {
        require(
            bondController != address(0),
            "Bond Dispatcher: zero address detected"
        );
        ERC20 payoutToken;
        ERC20 quoteToken;
        uint48 vesting;

        // calculate fees for purchase via protocol fee
        uint256 toProtocol = amount_.mulDiv(protocolFee, FEE_DECIMALS);

        (, payoutToken, quoteToken, vesting, ) = IBondController(bondController)
            .getMarketInfoForPurchase(id_);

        // bond controller handles bond pricing, capacity, and duration
        uint256 amountLessFee = amount_ - toProtocol;
        uint256 payout = IBondController(bondController).purchaseBond(
            marketId,
            amountLessFee,
            minAmountOut_
        );

        // allocate fees to protocol
        rewards[_protocol][quoteToken] += toProtocol;

        // ensure enough payout tokens are available
        _handleTransfers(id_, amount_, payout, toProtocol);
        // handle payout to user (either transfer tokens if instant swap or issue bond token)
        uint48 expiry = _handlePayout(recipient_, payout, payoutToken, vesting);

        emit Bonded(id_, amount_, payout);

        return (payout, expiry);
    }

    /// @notice handles transfer of funds from user and bond controller
    function _handleTransfers(
        uint256 marketId,
        uint256 amount_,
        uint256 payout_,
        uint256 feePaid_
    ) internal {
        require(
            bondController != address(0),
            "Bond Dispatcher: zero address detected"
        );
        // get info from controller
        (ERC20 payoutToken, ERC20 quoteToken, , ) = IBondController(
            bondController
        ).getMarketInfoForPurchase(id_);

        // calculate amount net of fees
        uint256 amountLessFee = amount_ - feePaid_;

        // note: currently dispatcher holding funds
        // transfer from msg sender to bond controller
        uint256 quoteBalance = quoteToken.balanceOf(address(this));
        quoteToken.safeTransferFrom(msg.sender, address(this), amount_);
        // check whether full amount recieved
        if (quoteToken.balanceOf(address(this)) < quoteBalance + amount_)
            revert Dispatcher_UnsupportedToken();

        // transfer tokens from bond controller -> dispatcher
        uint256 payoutBalance = payoutToken.balanceOf(address(this));
        payoutToken.safeTransferFrom(bondController, address(this), payout_);
        if (payoutToken.balanceOf(address(this)) < (payoutBalance + payout_))
            revert Dispatcher_UnsupportedToken();

        quoteToken.safeTransfer(bondController, amountLessFee);
    }

    /// @notice handle payout to recipient
    /// @dev must be implemented by inheriting contract
    /// @param recipient_ recipient of payout
    /// @param payout_ payout
    /// @param underlying_ token to be paid out
    /// @param vesting_ time parameter depending on implementation
    /// @return expiry timestamp when the payout will vest
    function _handlePayout(
        address recipient_,
        uint256 payout_,
        ERC20 underlying_,
        uint48 vesting_
    ) internal virtual returns (uint48 expiry);
}
