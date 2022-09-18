// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseSetup.t.sol";

contract GaugeControllerTest is BaseSetup {
    function testGetWeight() public {
        uint256 weight = gaugeController.get_total_weight();
        assertEq(0, weight);
    }
}