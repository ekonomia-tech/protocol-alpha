// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@protocol/interfaces/IPHO.sol";
import "@protocol/interfaces/IKernel.sol";
import "@protocol/interfaces/IModuleManager.sol";
import "@modules/mapleDepositModule/MapleDepositModule.sol";
import "./Addresses.sol";

/// Script to deploy Maple Deposit module
contract DeployMapleDepositModule is Script, Addresses {
    MapleDepositModule public mapleDepositModule;
    // Example below with USDC_USD pricefeed and Orthogonal USDC pool / rewards
    address oracleAddress = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address mplRewardsAddress = 0x7869D7a3B074b5fa484dc04798E254c9C06A5e90;
    address mplPoolAddress = 0xFeBd6F15Df3B73DC4307B1d7E65D46413e710C27;
    address depositTokenAddress = usdcAddress;

    function run() external {
        vm.startBroadcast();

        mapleDepositModule = new MapleDepositModule(
            moduleManagerAddress,
            kernelAddress,
            phoAddress,
            oracleAddress,
            depositTokenAddress,
            mplRewardsAddress,
            mplPoolAddress
        );

        console.log(
            "Deployed mapleDepositModule address: ",
            address(mapleDepositModule)
        );

        vm.stopBroadcast();
    }
}
