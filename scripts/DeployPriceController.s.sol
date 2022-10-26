// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@protocol/interfaces/IPHO.sol";
import "@protocol/interfaces/IKernel.sol";
import "@protocol/interfaces/IModuleManager.sol";
import "@modules/priceController/PriceController.sol";
import "@oracle/ChainlinkPriceFeed.sol";

import "./Addresses.sol";

/// Script to deploy protocol (PHO, TON, Kernel, ModuleManager)
contract DeployPriceController is Script, Addresses {

    IPHO public pho = IPHO(phoAddress);
    IKernel public kernel = IKernel(kernelAddress);
    IModuleManager public moduleManager = IModuleManager(moduleManagerAddress);
    ChainlinkPriceFeed public chainlinkOracle = ChainlinkPriceFeed(chainlinkOracleAddress);
    PriceController public priceController;

    function run() external {
        vm.startBroadcast();
        
        priceController = new PriceController(
            phoAddress,
            moduleManagerAddress,
            kernelAddress,
            chainlinkOracleAddress,
            curvePool,
            1 weeks,
            10 ** 4,
            50000,
            99000
        );
        
        vm.stopBroadcast();
    }
}
