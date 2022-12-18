// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

// Inspired from: https://github.com/convex-eth/platform/blob/ecea24d8ff6eb850134573e80cfc795d26805b76/contracts/contracts/interfaces/IGaugeController.sol

interface IGaugeController {
    function get_gauge_weight(address _gauge) external view returns (uint256);

    function vote_user_slopes(address, address) external view returns (uint256, uint256, uint256); //slope,power,end

    function vote_for_gauge_weights(address, uint256) external;

    function add_gauge(address, int128, uint256) external;

    function gauge_types(address _addr) external view returns (uint256);

    function voting_escrow() external view returns (address);

    function checkpoint_gauge(address addr) external;

    function gauge_relative_weight(address addr, uint256 time) external view returns (uint256);
}
