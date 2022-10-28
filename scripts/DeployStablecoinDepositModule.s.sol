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
    ERC20 public mockUSDC;

    function run() external {
        vm.startBroadcast();

        mockUSDC = new ERC20("Mock USDC", "mUSDC");
        stablecoinDepositModule = new StablecoinDepositModule(
            moduleManagerAddress,
            address(mockUSDC),
            kernelAddress,
            phoAddress
        );

        console.log(
            "Deployed stablecoinDepositModule address: ",
            address(stablecoinDepositModule)
        );

        vm.stopBroadcast();
    }
}
