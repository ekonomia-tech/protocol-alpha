// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice these are generic functions seen within stable swap vyper contracts deployed in other metapool contracts such as this one: https://etherscan.io/address/0x497CE58F34605B9944E6b15EcafE6b001206fd25#code
interface ICurvePool is IERC20 {
    function coins(uint256) external view returns (address);
    function get_virtual_price() external view returns (uint256);
    function calc_token_amount(uint256[] calldata, bool deposit) external view returns (uint256);
    function calc_withdraw_one_coin(uint256 _token_amount, int128)
        external
        view
        returns (uint256);
    function fee() external view returns (uint256);
    function get_dy(int128 i, int128 j, uint256 dx) external view returns (uint256);
    function get_dy_underlying(int128 i, int128 j, uint256 dx) external view returns (uint256);
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external returns (uint256);
    function exchange_underlying(int128 i, int128 j, uint256 dx, uint256 min_dy)
        external
        returns (uint256);
    function add_liquidity(uint256[2] memory amounts, uint256 min_mint_amount) external;
    function remove_liquidity_one_coin(uint256 _token_amount, int128 i, uint256 min_amount)
        external;
    function balances(uint256 _index) external returns (uint256);
    function lp_token() external view returns (address);
    function remove_liquidity(uint256 _burn_amount, uint256[2] memory _min_amounts, address _receiver) external returns (uint256[2] memory);
}
