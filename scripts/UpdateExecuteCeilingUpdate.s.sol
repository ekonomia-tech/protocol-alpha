// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@protocol/interfaces/IModuleManager.sol";
import "./Addresses.sol";

/// Script to deploy Stablecoin Deposit module
contract UpdateExecuteCeilingUpdate is Script, Addresses {

    IModuleManager public moduleManager;

    function run(string memory network, address moduleAddress) external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        address moduleManagerAddress = getAddress(network, ".ModuleManager");
        moduleManager = IModuleManager(moduleManagerAddress);
        moduleManager.executeCeilingUpdate(moduleAddress);

        vm.stopBroadcast();
    }
}
