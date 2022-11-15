// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IModuleAMO {
    // Creates tracking shares for user and does external calls as needed
    function stakeFor(address account, uint256 amount) external returns (bool);

    // Withdraw amount for user
    function withdrawFor(address account, uint256 amount) external;

    // Withdraw all for user
    function withdrawAllFor(address account) external;

    // Staking token
    function stakingToken() external view returns (address);

    // Reward token
    function rewardToken() external view returns (address);

    // Tracks earned amount per user
    function earned(address account) external view returns (uint256);
}
