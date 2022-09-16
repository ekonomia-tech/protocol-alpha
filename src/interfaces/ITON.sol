// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

interface ITON {
    event TONBurned(address indexed from, uint256 amount);

    function burn(address from, uint256 amount) external;
}
