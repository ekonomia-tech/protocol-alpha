// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IPHOTONKernel.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IPHO.sol";

/// @title PHOTONKernel Placeholder
/// @author Ekonomia: https://github.com/Ekonomia
contract PHOTONKernel is IPHOTONKernel, Ownable, ReentrancyGuard {
    uint256 public PHOCeiling;
    uint256 public totalPHOMinted;
    IPHO public pho;

    constructor(address _phoAddress) {
        PHOCeiling = (1000000000 * 10 ** 18); // 1 billion
        pho = IPHO(_phoAddress);
    }

    function mintPHO(address to, uint256 amount) external {
        pho.mint(to, amount);
        totalPHOMinted += amount;
    } // onlyModuleManager

    function burnPHO(address to, uint256 amount) external {
        pho.burnFrom(to, amount);
        totalPHOMinted -= amount;
    } // onlyModuleManager

    // global state
    function setPHOCeiling() external {} // onlyTONGovernance
    function updateModuleManagerDelay() external {} // 4 weeks. Rarely happens
    function updateDispatcherDelay() external {} // 4 weeks. Rarely happens
    function addModuleDelay() external {} // 2 weeks. For safe exit of angry people

    // managers
    function updateDispatcher() external {} // onlyTONGovernance
    function updateModuleManager() external {} // onlyTONGovernance

    function getPHOCeiling() external view returns (uint256) {
        return PHOCeiling;
    }

    function getTotalPHOMinted() external view returns (uint256) {
        return totalPHOMinted;
    }
}
