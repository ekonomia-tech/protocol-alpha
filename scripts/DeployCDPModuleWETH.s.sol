// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@modules/cdpModule/CDPPool.sol";
import "./Addresses.sol";

/// Script to deploy protocol (PHO, TON, Kernel, ModuleManager)
contract DeployCDPModuleWETH is Script, Addresses {

    CDPPool public wethPool;
    address public WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    
    function run() external {
        vm.startBroadcast();
        
        wethPool = new CDPPool(
            moduleManagerAddress,
            chainlinkOracleAddress,
            WETH_ADDRESS,
            170000,
            150000,
            1000 * 10 ** 18,
            500
        );
  
        vm.stopBroadcast();
    }
}
