// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IModuleTokenMinter {
    function mint(address, uint256) external;

    function burn(address, uint256) external;
}
