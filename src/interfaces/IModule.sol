// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IModule {
    function mintPHO(address to, uint256 amount) external;

    function burnPHO(address from, uint256 amount) external;
}
