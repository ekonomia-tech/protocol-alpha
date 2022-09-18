// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseSetup.t.sol";

// Artifact paths for deploying from the deps folder, assumes that the command is run from
// the project root.
string constant gcArtifact = 'artifacts/src/hardhat/GaugeController.vy/GaugeController.json';

interface GaugeContoller {
    function get_total_weight() external view returns (uint256);
}

contract GaugeControllerTest is BaseSetup {
    GaugeContoller public gaugeController;

    function setUp() public {
        address _gc = deployCode(gcArtifact, abi.encode("0x7997f32675bc0e67F66EE189913741076789136a", "0x7997f32675bc0e67F66EE189913741076789136a"));
        gaugeController = GaugeContoller(_gc);
    }

    function testGetWeight() public {
        uint256 weight = gaugeController.get_total_weight();
        assertEq(0, weight);
    }
}