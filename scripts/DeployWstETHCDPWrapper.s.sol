// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@modules/cdpModule/wstETHCDPWrapper.sol";
import "./Addresses.s.sol";

/// Script to deploy protocol (PHO, TON, Kernel, ModuleManager)
contract DeployWstETHCDPWrapper is Script, Addresses {

    wstETHCDPWrapper public wrapper;
    
    function run() external {
        vm.startBroadcast();

        address cdpAddress = getAddress(".CDPPool_wstETH");
        
        wrapper = new wstETHCDPWrapper(cdpAddress);
        
        vm.stopBroadcast();
    }
}
