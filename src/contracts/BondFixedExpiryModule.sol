// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {BondBaseModule} from "./BondBaseModule.sol";
import {IBondModule} from "../interfaces/IBondModule.sol";
import {IBondFixedExpiryModule} from "../interfaces/IBondFixedExpiryModule.sol";
import {TransferHelper} from "../libraries/TransferHelper.sol";
import {BondUtils} from "../libraries/BondUtils.sol";
import {FullMath} from "../libraries/FullMath.sol";
import {ERC20BondToken} from "./ERC20BondToken.sol";

/// @title Bond Fixed Expiry Module
/// @author Ekonomia: https://github.com/ekonomia-tech
/// @dev An implementation of the BondBaseModule for bond markets that vest with a fixed expiry
contract BondFixedExpiryModule is BondBaseModule, IBondFixedExpiryModule {
    using TransferHelper for ERC20;
    using FullMath for uint256;

    /// Events
    event ERC20BondTokenCreated(
        ERC20BondToken bondToken, ERC20 indexed underlying, uint48 indexed expiry
    );

    /// State vars
    mapping(ERC20 => mapping(uint48 => ERC20BondToken)) public bondTokens; // ERC20 bond tokens

    /// Constructor
    constructor(
        address _controllerAddress,
        address _phoAddress,
        address _tonAddress,
        address protocol_
    ) BondBaseModule(_controllerAddress, _phoAddress, _tonAddress, protocol_) {}

    /// @inheritdoc BondBaseModule
    function createMarket(bytes calldata params_) external override returns (uint256) {
        MarketParams memory params = abi.decode(params_, (MarketParams));
        uint256 marketId = _createMarket(params);

        // create ERC20 fixed expiry bond token
        deploy(params.payoutToken, params.vesting);

        return marketId;
    }

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
            bondTokens[underlying_][expiry].mint(recipient_, payout_); // mint ERC20 for fixed expiry
        } else {
            underlying_.transfer(recipient_, payout_); // transfer payout to user
        }
        return expiry;
    }

    /// Deposit / Mint

    /// @inheritdoc IBondFixedExpiryModule
    function create(ERC20 underlying_, uint48 expiry_, uint256 amount_)
        external
        override
        returns (ERC20BondToken, uint256)
    {
        ERC20BondToken bondToken = bondTokens[underlying_][expiry_];
        require(
            bondToken == ERC20BondToken(address(0x00)),
            "BondFixedExpiryDispatcher: Token does not exist"
        ); // token must exist, must call deploy first
        uint256 oldBalance = underlying_.balanceOf(address(this)); // transfer underlying
        underlying_.transferFrom(msg.sender, address(this), amount_);
        require(
            underlying_.balanceOf(address(this)) < oldBalance + amount_,
            "BondFixedExpiryDispatcher: transfer not full"
        );

        // calculate fee and then mint bond tokens
        if (protocolFee > 0) {
            uint256 feeAmount = amount_.mulDiv(protocolFee, FEE_DECIMALS);
            rewards[_protocol][underlying_] += feeAmount;
            bondToken.mint(msg.sender, amount_ - feeAmount);
            return (bondToken, amount_ - feeAmount);
        } else {
            bondToken.mint(msg.sender, amount_);
            return (bondToken, amount_);
        }
    }

    /// Redeem

    /// @inheritdoc IBondFixedExpiryModule
    function redeem(ERC20BondToken token_, uint256 amount_) external override {
        require(
            uint48(block.timestamp) >= token_.expiry(),
            "BondFixedExpiryDispatcher: cannot redeem before expiry"
        );
        token_.burn(msg.sender, amount_);
        token_.underlying().transfer(msg.sender, amount_);
    }

    /// Tokenization

    /// @inheritdoc IBondFixedExpiryModule
    function deploy(ERC20 underlying_, uint48 expiry_) public override returns (ERC20BondToken) {
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

    /// @inheritdoc IBondFixedExpiryModule
    function getBondTokenForMarket(uint256 marketId)
        external
        view
        override
        returns (ERC20BondToken)
    {
        (ERC20 underlying,, uint48 vesting,) = getMarketInfoForPurchase(marketId);
        return bondTokens[underlying][vesting];
    }
}
