// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@protocol/interfaces/IKernel.sol";
import "@protocol/interfaces/IPHO.sol";

contract Kernel is IKernel {
    IPHO public pho;

    // uint256 PHOCeiling;
    // uint256 totalPHOMinted;
    uint256 public moduleManagerDelay = 4 weeks;
    uint256 public moduleDelay = 2 weeks;

    address public moduleManager;
    address public TONGovernance;

    modifier onlyModuleManager() {
        if (msg.sender != moduleManager) revert NotModuleManager(msg.sender);
        _;
    }

    modifier onlyTONGovernance() {
        if (msg.sender != TONGovernance) revert NotTONGovernance(msg.sender);
        _;
    }

    /// @param _pho the $PHO contract address
    /// @param _TONGovernance the governance address for $TON
    constructor(address _pho, address _TONGovernance) {
        if (_pho == address(0) || _TONGovernance == address(0)) {
            revert ZeroAddress();
        }
        pho = IPHO(_pho);
        TONGovernance = _TONGovernance;
    }

    /// @notice function to mint $PHO that can be called only by moduleManager
    /// @param to the address to which $PHO will be minted to
    /// @param amount the amount of $PHO to be minted
    function mintPHO(address to, uint256 amount) external onlyModuleManager {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroValue();
        pho.mint(to, amount);
    }

    /// @notice function to burn $PHO that can be called only by moduleManager
    /// @param from the address to burn $PHO from
    /// @param amount the amount of $PHO to burn
    function burnPHO(address from, uint256 amount) external onlyModuleManager {
        if (from == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroValue();
        pho.burnFrom(from, amount);
    }

    // function setPHOCeiling(uint256 newCeiling) external onlyTONGovernance {
    //     if (newCeiling < totalPHOMinted) {
    //         revert CeilingLowerThanTotalMinted(totalPHOMinted, PHOCeiling);
    //     }
    //     PHOCeiling = newCeiling;
    //     emit PHOCeilingUpdated(newCeiling);
    // }

    /// @notice function to update the module manager delay for updating a module manager
    /// @param newDelay the new delay in seconds
    function updateModuleManagerDelay(uint256 newDelay) external onlyTONGovernance {
        if (newDelay == 0) revert ZeroValue();
        if (newDelay == moduleManagerDelay) revert SameValue();
        moduleManagerDelay = newDelay;
        emit ModuleManagerDelayUpdated(newDelay);
    }

    /// @notice update the module manager address in the kernel
    /// @param newModuleManager the new module manager address
    function updateModuleManager(address newModuleManager) external onlyTONGovernance {
        if (newModuleManager == address(0)) revert ZeroAddress();
        if (newModuleManager == moduleManager) revert SameAddress();
        moduleManager = newModuleManager;
        emit ModuleManagerUpdated(newModuleManager);
    }
}
