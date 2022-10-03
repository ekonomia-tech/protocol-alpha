// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

interface IPriceOracle {
    function getPrice(address baseToken) external view returns (uint256);
}
