// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseSetup.t.sol";

contract GaugeControllerTest is BaseSetup {
    function testGetWeight() public {
        uint256 weight = gaugeController.get_total_weight();
        assertEq(0, weight);
    }

    function testGetVeTONDetails() public {
        assertEq(voteEscrow.name(), "veTON");
        assertEq(voteEscrow.symbol(), "veTON");
        assertEq(voteEscrow.decimals(), 18);
        assertEq(voteEscrow.token(), address(ton));
    }
}