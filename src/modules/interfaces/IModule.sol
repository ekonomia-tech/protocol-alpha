// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IModule {
    function deposit(uint256) external;

    function redeem() external;

    function rewardClaimed(address, uint256) external returns (bool);

    function withdrawTo(uint256, address) external returns (bool);
}
