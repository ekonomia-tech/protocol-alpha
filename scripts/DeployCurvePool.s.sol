// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "@protocol/contracts/PHO.sol";
import "@external/curve/ICurveFactory.sol";
import "@external/curve/ICurvePool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Addresses.sol";

/// Script to deploy protocol (PHO, TON, Kernel, ModuleManager)
contract DeployCurvePool is Script, Addresses {

    address fraxBP = 0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2;
    ICurveFactory curveFactory = ICurveFactory(0xB9fC157394Af804a3578134A6585C0dc9cc990d4);

    function run() external {
        vm.startBroadcast();

        address curvePoolAddress = curveFactory.deploy_metapool(
            fraxBP, "FRAXBP/PHO", "FRAXBPPHO", phoAddress, 200, 4000000, 0
        );

        console.log(curvePoolAddress);
        
        vm.stopBroadcast();
    }
}
