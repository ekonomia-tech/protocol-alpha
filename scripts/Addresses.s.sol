// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "forge-std/Script.sol";

abstract contract Addresses is Script {

    function getAddress(string memory field) public returns (address) {
        string memory path = "deployments/addresses_last.json";
        string memory j = vm.readFile(path);
        bytes memory json = vm.parseJson(j, field);
        address res = abi.decode(json, (address));
        return res;
    }

    function getAddress(string memory network, string memory field) public returns (address) {
        string memory path = string.concat("deployments/", network ,"/addresses_latest.json");
        string memory j = vm.readFile(path);
        bytes memory json = vm.parseJson(j, field);
        address res = abi.decode(json, (address));
        return res;
    }

}