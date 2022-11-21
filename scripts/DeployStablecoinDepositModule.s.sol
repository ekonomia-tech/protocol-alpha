// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@protocol/interfaces/IPHO.sol";
import "@protocol/interfaces/IKernel.sol";
import "@protocol/interfaces/IModuleManager.sol";
import "@modules/stablecoinDepositModule/StablecoinDepositModule.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Addresses.sol";

/// Script to deploy Stablecoin Deposit module
contract DeployStablecoinDepositModule is Script, Addresses {
    StablecoinDepositModule public stablecoinDepositModule;

    function run(address depositToken) external {
        vm.startBroadcast();

        address phoAddress = getAddress(".PHO");
        address moduleManagerAddress = getAddress(".ModuleManager");
        address kernelAddress = getAddress(".Kernel");
        
        stablecoinDepositModule = new StablecoinDepositModule(
            moduleManagerAddress,
            depositToken,
            kernelAddress,
            phoAddress
        );

        vm.stopBroadcast();
    }
}
