// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseSetup.t.sol";

// Artifact paths for deploying from the deps folder, assumes that the command is run from
// the project root.
string constant gcArtifact = 'artifacts/src/hardhat/GaugeController.vy/GaugeController.json';

contract GaugeControllerTest is BaseSetup {
    function setUp() public {
        console.log("STEVENDEBUG GaugeControllerTest.setUp()");

        address _gcArtifact = deployCode(gcArtifact);
    }

    function testSomething() public {
        console.log("STEVENDEBUG GaugeControllerTest.testSomething()");
    }
}