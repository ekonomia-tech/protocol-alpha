// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@protocol/interfaces/IPHO.sol";
import "@protocol/interfaces/IKernel.sol";
import "@protocol/interfaces/IModuleManager.sol";
import "@modules/priceController/PriceController.sol";
import "@oracle/ChainlinkPriceFeed.sol";

import "./Addresses.s.sol";

/// Script to deploy protocol (PHO, TON, Kernel, ModuleManager)
contract DeployPriceController is Script, Addresses {

    PriceController public priceController;

    function run(uint256 cooldownPeriod, uint256 priceBand, uint256 priceMitigationPercentage, uint256 maxSlippage) external {
        vm.startBroadcast();

        address phoAddress = getAddress(".PHO");
        address moduleManagerAddress = getAddress(".ModuleManager");
        address kernelAddress = getAddress(".Kernel");
        address chainlinkPriceFeedAddress = getAddress(".ChainlinkPriceFeed");
        address curvePoolAddress = getAddress(".CurvePool"); 

        priceController = new PriceController(
            phoAddress,
            moduleManagerAddress,
            kernelAddress,
            chainlinkPriceFeedAddress,
            curvePoolAddress,
            cooldownPeriod,
            priceBand,
            priceMitigationPercentage,
            maxSlippage
        );
        
        vm.stopBroadcast();
    }
}
