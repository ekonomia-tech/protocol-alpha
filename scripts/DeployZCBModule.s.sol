// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@protocol/interfaces/IPHO.sol";
import "@protocol/interfaces/IKernel.sol";
import "@protocol/interfaces/IModuleManager.sol";
import "@modules/zeroCouponBondModule/ZeroCouponBondModule.sol";
import "./Addresses.s.sol";

/// Script to deploy ZCB module
contract DeployZCBModule is Script, Addresses {
    
    ZeroCouponBondModule public zeroCouponBondModule;

    function run(
        address depositToken, 
        string memory bondTokenName, 
        string memory bondTokenSymbol, 
        uint256 interestRate, 
        uint256 depositWindowOpen, 
        uint256 depositWindowEnd
    ) external {
        vm.startBroadcast();

        address phoAddress = getAddress(".PHO");
        address moduleManagerAddress = getAddress(".ModuleManager");
        address kernelAddress = getAddress(".Kernel");

        zeroCouponBondModule = new ZeroCouponBondModule(
            moduleManagerAddress,
            kernelAddress,
            phoAddress,
            depositToken,
            bondTokenName,
            bondTokenSymbol,
            interestRate,
            block.timestamp + depositWindowOpen,
            block.timestamp + depositWindowEnd
        );

        vm.stopBroadcast();
    }
}
