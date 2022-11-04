// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IModuleRewardPool {
    function stake(address, uint256) external returns (bool);

    function stakeFor(address, uint256) external returns (bool);

    function withdraw(address, uint256) external;

    function getReward(address, bool) external returns (bool);

    function queueNewRewards(uint256) external returns (bool);

    function notifyRewardAmount(uint256) external;

    function addExtraReward(address) external;

    function stakingToken() external view returns (address);

    function rewardToken() external view returns (address);

    function earned(address account) external view returns (uint256);
}
