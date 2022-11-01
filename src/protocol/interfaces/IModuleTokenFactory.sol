// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IModuleTokenFactory {
    function createModuleDepositToken(address) external returns (address);
}
