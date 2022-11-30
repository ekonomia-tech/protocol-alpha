// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

// Inspired from: https://github.com/convex-eth/platform/blob/ecea24d8ff6eb850134573e80cfc795d26805b76/contracts/contracts/Interfaces.sol
interface ICurveGauge {
    function balanceOf(address) external view returns (uint256);

    function claim_rewards() external;

    function deposit(uint256 _amount) external;

    function withdraw(uint256 _amount) external;

    function lp_token() external view returns (address);

    function reward_tokens(uint256 index) external view returns (address);

    function claimable_reward(address, address) external view returns (uint256);
}
