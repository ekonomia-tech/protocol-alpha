// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IModuleDispatcher {
    function modulePoolInfo(uint256)
        external
        view
        returns (address, address, address, address, address, address);

    function rewardClaimed(uint256, address, uint256) external returns (bool);

    function withdrawTo(uint256, uint256, address) external returns (bool);

    function claimRewards(uint256, address) external returns (bool);

    function owner() external returns (address);
}
