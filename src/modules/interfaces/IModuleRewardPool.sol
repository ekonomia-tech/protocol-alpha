// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IModuleRewardPool {
    // NEED: Creates tracking shares for user
    function stakeFor(address, uint256) external returns (bool);

    // NEED: TODO: rename to withdrawFor
    function withdraw(address, uint256) external;

    // NEED: withdrawAllFor
    function withdrawAllFor(address, uint256) external;

    // NEED: Keep rest as is
    function getReward(address, bool) external returns (bool);

    function queueNewRewards(uint256) external returns (bool);

    function notifyRewardAmount(uint256) external;

    function stakingToken() external view returns (address);

    function rewardToken() external view returns (address);

    function earned(address account) external view returns (uint256);
}
