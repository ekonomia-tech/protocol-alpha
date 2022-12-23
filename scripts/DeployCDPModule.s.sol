// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@modules/cdpModule/CDPPool.sol";
import "./Addresses.s.sol";

/// Script to deploy protocol (PHO, TON, Kernel, ModuleManager)
contract DeployCDPModule is Script, Addresses {

    CDPPool public pool;
    
    function run(address depositToken, uint256 minCR, uint256 liquidationCR, uint256 minDebt, uint256 protocolFee) external {
        vm.startBroadcast();
        
        address moduleManagerAddress = getAddress(".ModuleManager");
        address TONTimelock = getAddress(".tonGovernance");
        address chainlinkPriceOracle = getAddress(".ChainlinkPriceFeed");
        
        pool = new CDPPool(
            moduleManagerAddress,
            chainlinkPriceOracle,
            depositToken,
            TONTimelock,
            minCR,
            liquidationCR,
            minDebt * 10 ** 18,
            protocolFee
        );
  
        vm.stopBroadcast();
    }
}
