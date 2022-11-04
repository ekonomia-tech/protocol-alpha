// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IStakingAMO {
    // Views
    function rewardsToken() external view returns (address);

    function periodFinish() external view returns (uint256);

    function balanceOf(address) external view returns (uint256);

    function lastUpdateTime() external view returns (uint256);

    function rewardPerToken() external view returns (uint256);

    function earned(address) external view returns (uint256);

    function lastTimeRewardApplicable() external view returns (uint256);

    function userRewardPerTokenPaid(address) external view returns (uint256);

    // Mutative
    function stake(uint256) external;

    function withdraw(uint256) external;

    function getReward() external;

    function exit() external;
}
