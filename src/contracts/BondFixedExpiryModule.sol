// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {BondBaseModule} from "./BondBaseModule.sol";
import {IBondModule} from "../interfaces/IBondModule.sol";
import {IBondFixedExpiryModule} from "../interfaces/IBondFixedExpiryModule.sol";
import {BondUtils} from "../libraries/BondUtils.sol";
import {ERC20BondToken} from "./ERC20BondToken.sol";

/// @title Bond Fixed Expiry Module
/// @author Ekonomia: https://github.com/ekonomia-tech
/// @dev An implementation of the BondBaseModule for bond markets with fixed termEnd
contract BondFixedExpiryModule is BondBaseModule, IBondFixedExpiryModule {
    using SafeERC20 for ERC20;

    /// Events
    event ERC20BondTokenCreated(
        ERC20BondToken bondToken, ERC20 indexed payoutToken, uint256 indexed termEnd
    );

    /// State vars
    mapping(ERC20 => mapping(uint256 => ERC20BondToken)) public bondTokens; // ERC20 bond tokens

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

        // create ERC20 fixed termEnd bond token
        deploy(params.payoutToken, params.termEnd);

        return marketId;
    }

    /// Purchase

    /// @notice handle payout to recipient
    /// @param recipient address to receive payout
    /// @param payout amount of payoutToken to be paid
    /// @param payoutToken token to be paid out
    /// @param termEnd timestamp when the payout will vest
    /// @return termEnd timestamp when the payout will vest
    function _handlePayout(address recipient, uint256 payout, ERC20 payoutToken, uint256 termEnd)
        internal
        override
        returns (uint256)
    {
        if (termEnd >= block.timestamp) {
            bondTokens[payoutToken][termEnd].mint(recipient, payout); // mint ERC20 for fixed termEnd
        } else {
            payoutToken.transfer(recipient, payout); // transfer payout to user
        }
        return termEnd;
    }

    /// Redeem

    /// @inheritdoc IBondFixedExpiryModule
    function redeem(ERC20BondToken token, uint256 amount_) external override {
        require(uint256(block.timestamp) >= token.termEnd(), "cannot redeem before termEnd");
        token.burn(msg.sender, amount_);
        token.payoutToken().transfer(msg.sender, amount_);
    }

    /// Tokenization

    /// @inheritdoc IBondFixedExpiryModule
    function deploy(ERC20 payoutToken, uint256 termEnd)
        public
        override
        onlyOwner
        returns (ERC20BondToken)
    {
        // create bond token if one doesn't already exist
        ERC20BondToken bondToken = bondTokens[payoutToken][termEnd];
        if (bondToken == ERC20BondToken(address(0))) {
            (string memory name, string memory symbol) =
                BondUtils._getNameAndSymbol(payoutToken, termEnd);
            bondToken = new ERC20BondToken(
                name,
                symbol,
                IERC20Metadata(payoutToken).decimals(),
                payoutToken,
                termEnd,
                address(this)
            );
            bondTokens[payoutToken][termEnd] = bondToken;
            emit ERC20BondTokenCreated(bondToken, payoutToken, termEnd);
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
        (ERC20 payoutToken,, uint256 termEnd,) = getMarketInfoForPurchase(marketId);
        return bondTokens[payoutToken][termEnd];
    }
}
