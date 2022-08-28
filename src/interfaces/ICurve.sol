// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

/// @notice these are generic functions seen within stableswap vyper contracts deployed in other metapool contracts such as this one: https://etherscan.io/address/0x497CE58F34605B9944E6b15EcafE6b001206fd25#code
interface ICurve {

    function coins(uint256) external view returns (address);
    function get_virtual_price() external view returns (uint256);
    function calc_token_amount(uint256[] calldata, bool deposit) external view returns (uint256);
    function calc_withdraw_one_coin(uint256 _token_amount, int128) external view returns (uint256);
    function fee() external view returns (uint256);
    function get_dy(int128 i, int128 j, uint256 dx) external view returns (uint256);
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external;
    function add_liquidity(uint256[] calldata amounts, uint256 min_mint_amount) external;
    function remove_liquidity_one_coin(uint256 _token_amount, int128 i, uint256 min_amount) external;
    
}
