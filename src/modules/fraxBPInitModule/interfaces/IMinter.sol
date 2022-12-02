// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

// TODO:
// https://github.com/InsureDAO/dao-contracts/blob/develop/contracts/interfaces/dao/IMinter.sol

import "./IGaugeController.sol";

interface IMinter {
    function token() external view returns (address);

    function controller() external view returns (address);

    function minted(address user, address gauge) external view returns (uint256);
}
