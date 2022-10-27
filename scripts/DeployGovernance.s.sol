// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "forge-std/Script.sol";
// import "@protocol/contracts/PHO.sol";
// import "@protocol/contracts/TON.sol";
// import "@protocol/contracts/Kernel.sol";
// import "@protocol/contracts/ModuleManager.sol";
// import "@oracle/ChainlinkPriceFeed.sol";
import "@governance/PHOGovernorBravoDelegate.sol";
import "@governance/PHOGovernorBravoDelegator.sol";
import "@governance/TONGovernorBravoDelegate.sol";
import "@governance/TONGovernorBravoDelegator.sol";
import "./Addresses.sol";

/// TODO - governance deployment script instead of having it in DeployProtocol. Have it run before the rest of this script, and have it populate the governance addresses accordingly that are needed for the contracts within this "core" script.
contract DeployGovernance is Script, Addresses {

    // PHO public pho;
    // TON public ton;
    // Kernel public kernel;
    // ModuleManager public moduleManager;
    // ChainlinkPriceFeed public chainlinkOracle;
    
    TONGovernorBravoDelegator public tonGovernorDelegator;
    PHOGovernorBravoDelegator public phoGovernorDelegator;
    TONGovernorBravoDelegate public tonGovernorDelegate;
    PHOGovernorBravoDelegate public phoGovernorDelegate; 

    function run() external {
        vm.startBroadcast();

        pho = new PHO("PHO", "PHO");
        ton = new TON("TON", "TON");

        // instantiate new governance contracts, although this could be done outside of this I guess.
        tonGovernorDelegate = new TONGovernorBravoDelegate();
        phoGovernorDelegate = new PHOGovernorBravoDelegate();
        
        // TODO - fill in the params needed for this
        phoGovernorDelegator = new PHOGovernorBravoDelegator();
        phoGovernance = address(phoGovernorDelegate);

        // TODO - fill in the params needed for this
        tonGovernorDelegator = new TONGovernorBravoDelegator();
        tonGovernance = address(tonGovernorDelegate);
        
        vm.stopBroadcast();
    }
}
