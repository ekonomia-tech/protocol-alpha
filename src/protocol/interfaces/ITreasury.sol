// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface ITreasury {
    error ZeroAddress();
    error ZeroValue();
    error Unauthorized();

    event Withdrawn(address indexed to, address indexed asset, uint256 amount);

    function withdrawTokens(address to, address asset, uint256 amount) external;
    function withdrawETH(address payable to, uint256 amount) external;
}
