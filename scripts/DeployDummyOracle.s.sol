// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@oracle/DummyOracle.sol";

contract DeployDummyOracle is Script {

    DummyOracle public oracle;
    
    function run() external {
        vm.startBroadcast();
        
        oracle = new DummyOracle();
        
        vm.stopBroadcast();
    }
}
