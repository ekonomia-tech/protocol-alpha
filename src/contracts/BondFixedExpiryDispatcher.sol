// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {BondBaseDispatcher} from "./BondBaseDispatcher.sol";
import {IBondController} from "../interfaces/IBondController.sol";
import {IBondFixedExpiryDispatcher} from "../interfaces/IBondFixedExpiryDispatcher.sol";
import {ERC20BondToken} from "./ERC20BondToken.sol";
import {TransferHelper} from "../libraries/TransferHelper.sol"; // TODO: modify
import {FullMath} from "../libraries/FullMath.sol";
import {BondUtils} from "../libraries/BondUtils.sol";

/// @title Bond Fixed Expiry Dispatcher
/// @author Ekonomia: https://github.com/ekonomia-tech
/// @dev An implementation of the BondBaseDispatcher for bond markets with fixed term using ERC20 tokens
contract BondFixedExpiryDispatcher is BondBaseDispatcher, IBondFixedExpiryDispatcher {
    using TransferHelper for ERC20;
    using FullMath for uint256;

    /// Errors
    error Dispatcher_TokenNotMatured(uint48 maturesOn);

    /// Events
    event ERC20BondTokenCreated(
        ERC20BondToken bondToken, ERC20 indexed underlying, uint48 indexed expiry
    );

    /// State vars
    /// @notice ERC20 bond tokens (unique to a underlying and expiry)
    mapping(ERC20 => mapping(uint48 => ERC20BondToken)) public bondTokens;

    /// @notice ERC20BondToken - can modify later for cloning
    // ERC20BondToken public immutable bondTokenImplementation;

    /// Constructor
    constructor(address protocol_, address _controllerAddress)
        BondBaseDispatcher(protocol_, _controllerAddress)
    {}

    /// Purchase

    /// @notice handle payout to recipient
    /// @param recipient_ address to receive payout
    /// @param payout_ amount of payoutToken to be paid
    /// @param underlying_ token to be paid out
    /// @param vesting_ timestamp when the payout will vest
    /// @return expiry timestamp when the payout will vest
    function _handlePayout(address recipient_, uint256 payout_, ERC20 underlying_, uint48 vesting_)
        internal
        override
        returns (uint48)
    {
        uint48 expiry;
        if (vesting_ > uint48(block.timestamp)) {
            expiry = vesting_;
            // fixed-expiry bonds mint ERC-20 tokens
            bondTokens[underlying_][expiry].mint(recipient_, payout_);
        } else {
            // if no expiry, then transfer payout directly to user
            underlying_.transfer(recipient_, payout_);
        }
        return expiry;
    }

    /// Deposit / Mint

    /// @inheritdoc IBondFixedExpiryDispatcher
    function create(ERC20 underlying_, uint48 expiry_, uint256 amount_)
        external
        override
        nonReentrant
        returns (ERC20BondToken, uint256)
    {
        ERC20BondToken bondToken = bondTokens[underlying_][expiry_];

        // revert if no token exists, must call deploy first
        if (bondToken == ERC20BondToken(address(0x00))) {
            revert Dispatcher_TokenDoesNotExist(underlying_, expiry_);
        }

        // transfer in underlying
        uint256 oldBalance = underlying_.balanceOf(address(this));
        underlying_.transferFrom(msg.sender, address(this), amount_);
        if (underlying_.balanceOf(address(this)) < oldBalance + amount_) {
            revert Dispatcher_UnsupportedToken();
        }

        // calculate fee and store it
        if (protocolFee > 0) {
            uint256 feeAmount = amount_.mulDiv(protocolFee, FEE_DECIMALS);
            rewards[_protocol][underlying_] += feeAmount;

            // mint new bond tokens
            bondToken.mint(msg.sender, amount_ - feeAmount);
            return (bondToken, amount_ - feeAmount);
        } else {
            // mint new bond tokens
            bondToken.mint(msg.sender, amount_);
            return (bondToken, amount_);
        }
    }

    /// Redeem

    /// @inheritdoc IBondFixedExpiryDispatcher
    function redeem(ERC20BondToken token_, uint256 amount_) external override nonReentrant {
        if (uint48(block.timestamp) < token_.expiry()) {
            revert Dispatcher_TokenNotMatured(token_.expiry());
        }
        token_.burn(msg.sender, amount_);
        token_.underlying().transfer(msg.sender, amount_);
    }

    /// Tokenization

    /// @inheritdoc IBondFixedExpiryDispatcher
    function deploy(ERC20 underlying_, uint48 expiry_)
        external
        override
        nonReentrant
        returns (ERC20BondToken)
    {
        // create bond token if one doesn't already exist
        ERC20BondToken bondToken = bondTokens[underlying_][expiry_];
        if (bondToken == ERC20BondToken(address(0))) {
            (string memory name, string memory symbol) =
                BondUtils._getNameAndSymbol(underlying_, expiry_);
            bondToken = new ERC20BondToken(
                name,
                symbol,
                IERC20Metadata(underlying_).decimals(),
                underlying_,
                expiry_,
                address(this)
            );
            bondTokens[underlying_][expiry_] = bondToken;
            emit ERC20BondTokenCreated(bondToken, underlying_, expiry_);
        }
        return bondToken;
    }

    /// @inheritdoc IBondFixedExpiryDispatcher
    function getBondTokenForMarket(uint256 marketId)
        external
        view
        override
        returns (ERC20BondToken)
    {
        (ERC20 underlying,, uint48 vesting,) =
            IBondController(bondController).getMarketInfoForPurchase(marketId);
        return bondTokens[underlying][vesting];
    }
}
