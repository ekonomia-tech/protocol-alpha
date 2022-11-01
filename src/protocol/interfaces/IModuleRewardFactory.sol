// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IModuleRewardFactory {
    function setAccess(address, bool) external;

    function createRewards(uint256, address, address) external returns (address);

    function createTokenRewards(address, address, address) external returns (address);

    function activeRewardCount(address) external view returns (uint256);

    function addActiveReward(address, uint256) external returns (bool);

    function removeActiveReward(address, uint256) external returns (bool);
}
