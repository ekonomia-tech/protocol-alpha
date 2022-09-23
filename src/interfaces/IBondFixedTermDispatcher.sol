// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IBondFixedTermDispatcher {
    // Info for bond token
    struct TokenMetadata {
        bool active;
        ERC20 payoutToken;
        uint48 expiry;
        uint256 supply;
    }

    /// @notice deposit an ERC20 token and mint a future-dated ERC1155 bond token
    /// @param underlying_ ERC20 token redeemable when the bond token vests
    /// @param expiry_ timestamp at which the bond token can be redeemed for the underlying token
    /// @param amount_ amount of underlying tokens to deposit
    /// @return id of the ERC1155 bond token received
    /// @return amount of the ERC1155 bond token received
    function create(
        ERC20 underlying_,
        uint48 expiry_,
        uint256 amount_
    ) external returns (uint256, uint256);

    /// @notice deploy a new ERC1155 bond token for an (underlying, expiry) pair and return its address
    /// @dev ERC1155 used for fixed-term
    /// @dev if a bond token exists for the (underlying, expiry) pair, it returns that address
    /// @param underlying_ ERC20 token redeemable when the bond token vests
    /// @param expiry_ timestamp at which the bond token can be redeemed for the underlying token
    /// @return id of the ERC1155 bond token being created
    function deploy(ERC20 underlying_, uint48 expiry_)
        external
        returns (uint256);

    /// @notice redeem a fixed-term bond token for the underlying token (bond token must have matured)
    /// @param tokenId_ id of the bond token to redeem
    /// @param amount_ amount of bond token to redeem
    function redeem(uint256 tokenId_, uint256 amount_) external;

    /// @notice redeem multiple fixed-term bond tokens for the underlying tokens (bond tokens must have matured)
    /// @param tokenIds_ array of bond token ids
    /// @param amounts_ array of amounts of bond tokens to redeem
    function batchRedeem(uint256[] memory tokenIds_, uint256[] memory amounts_)
        external;

    /// @notice get token ID from token and expiry
    /// @param payoutToken_ payout token of bond
    /// @param expiry_ expiry of the bond
    /// @return id of the bond token
    function getTokenId(ERC20 payoutToken_, uint48 expiry_)
        external
        pure
        returns (uint256);

    /// @notice get the token name and symbol for a bond token
    /// @param tokenId_ id of the bond token
    /// @return name bond token name
    /// @return symbol bond token symbol
    function getTokenNameAndSymbol(uint256 tokenId_)
        external
        view
        returns (string memory, string memory);
}
