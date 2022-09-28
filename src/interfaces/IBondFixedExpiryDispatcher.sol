// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20BondToken} from "../contracts/ERC20BondToken.sol";

interface IBondFixedExpiryDispatcher {
    /// @notice redeem a fixed-expiry bond token for the underlying token (bond token must have matured)
    /// @param token_ token to redeem
    /// @param amount_ amount to redeem
    function redeem(ERC20BondToken token_, uint256 amount_) external;

    /// @notice deposit an ERC20 token and mint a future-dated ERC20 bond token
    /// @param underlying_ ERC20 token redeemable when the bond token vests
    /// @param expiry_ timestamp at which the bond token can be redeemed for the underlying token
    /// @param amount_ amount of underlying tokens to deposit
    /// @return address of the ERC20 bond token received
    /// @return address of the ERC20 bond token received
    function create(
        ERC20 underlying_,
        uint48 expiry_,
        uint256 amount_
    ) external returns (ERC20BondToken, uint256);

    /// @notice deploy a new ERC20 bond token for an (underlying, expiry) pair and return its address
    /// @dev ERC20 used for fixed-expiry
    /// @dev if a bond token exists for the (underlying, expiry) pair, it returns that address
    /// @param underlying_ ERC20 token redeemable when the bond token vests
    /// @param expiry_ timestamp at which the bond token can be redeemed for the underlying token
    /// @return address of the ERC20 bond token being created
    function deploy(ERC20 underlying_, uint48 expiry_)
        external
        returns (ERC20BondToken);

    /// @notice get the ERC20BondToken contract corresponding to a market
    /// @param marketId id of the market
    /// @return ERC20BondToken contract address
    function getBondTokenForMarket(uint256 marketId)
        external
        view
        returns (ERC20BondToken);
}
