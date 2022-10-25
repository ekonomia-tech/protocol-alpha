// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@protocol/contracts/PHO.sol";
import "@protocol/contracts/TON.sol";
import "@protocol/contracts/Kernel.sol";
import "@protocol/contracts/ModuleManager.sol";
import "@oracle/ChainlinkPriceFeed.sol";
import "./Addresses.sol";

/// Script to deploy protocol (PHO, TON, Kernel, ModuleManager)
contract DeployProtocol is Script, Addresses {

    PHO public pho;
    TON public ton;
    Kernel public kernel;
    ModuleManager public moduleManager;
    ChainlinkPriceFeed public chainlinkOracle;

    function run() external {
        vm.startBroadcast();

        phoGovernance = msg.sender;
        tonGovernance = msg.sender;

        pho = new PHO("PHO", "PHO");
        ton = new TON("TON", "TON");
        kernel = new Kernel(address(pho), tonGovernance);
        moduleManager = new ModuleManager(
            address(kernel),
            phoGovernance,
            tonGovernance
        );
        chainlinkOracle = new ChainlinkPriceFeed(10);
        pho.setKernel(address(kernel));
        kernel.updateModuleManager(address(moduleManager));
        
        vm.stopBroadcast();
    }
}
