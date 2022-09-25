// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

interface IPriceOracle {
    function getPrice(address base) external view returns (uint256);
}