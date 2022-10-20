// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@protocol/interfaces/IPHO.sol";
import "@protocol/interfaces/IModuleManager.sol";
import "@protocol/interfaces/IKernel.sol";

/// @title ModuleManager
/// @notice Intermediary between Modules and Kernel
/// @author Ekonomia: https://github.com/Ekonomia
contract ModuleManager is IModuleManager {
    IKernel public kernel;
    address public PHOGovernance;
    address public TONGovernance;
    uint256 public moduleDelay;

    mapping(address => Module) public modules;

    /// modifiers

    modifier onlyModule() {
        if (modules[msg.sender].status != Status.Registered) {
            revert UnregisteredModule(msg.sender);
        }
        _;
    }

    modifier onlyPHOGovernance() {
        if (msg.sender != PHOGovernance) revert NotPHOGovernance(msg.sender);
        _;
    }

    modifier onlyTONGovernance() {
        if (msg.sender != TONGovernance) revert NotTONGovernance(msg.sender);
        _;
    }

    /// NOTE -  need to setKernel right after initial deployment of ModuleManager
    constructor(address _kernel, address _PHOGovernance, address _TONGovernance) {
        if (_kernel == address(0) || _PHOGovernance == address(0) || _TONGovernance == address(0)) {
            revert ZeroAddress();
        }
        kernel = IKernel(_kernel);
        PHOGovernance = _PHOGovernance;
        TONGovernance = _TONGovernance;
        moduleDelay = 2 weeks;
    }

    /// @notice updates module accounting && mints PHO through Kernel
    /// @param _to the user address to be minted $PHO
    /// @param _amount total PHO to be minted
    function mintPHO(address _to, uint256 _amount) external override onlyModule {
        if (_amount == 0) revert ZeroValue();
        Module storage module = modules[msg.sender];
        if (module.phoMinted + _amount > module.phoCeiling) revert ModuleCeilingExceeded();
        module.phoMinted = module.phoMinted + _amount;
        kernel.mintPHO(_to, _amount);
        emit ModuleMint(msg.sender, _to, _amount);
    }

    /// @notice updates module accounting && burns PHO through Kernel
    /// @param _from the user that $PHO will be burned from
    /// @param _amount total PHO to be burned
    function burnPHO(address _from, uint256 _amount) external override {
        if (modules[msg.sender].status == Status.Unregistered) {
            revert UnregisteredModule(msg.sender);
        }
        if (_amount == 0) revert ZeroValue();
        Module storage module = modules[msg.sender];
        if ((module.phoMinted <= _amount)) revert ModuleBurnExceeded();
        kernel.burnPHO(_from, _amount);
        module.phoMinted = module.phoMinted - _amount;
        emit ModuleBurn(msg.sender, _from, _amount);
    }

    /// @notice adds new module to registry
    /// @param _newModule address of module to add
    function addModule(address _newModule) external override onlyPHOGovernance {
        Module storage module = modules[_newModule];
        if (_newModule == address(0)) revert ZeroAddress();
        if (module.status != Status.Unregistered) revert ModuleRegistered();
        module.status = Status.Registered;
        module.startTime = block.timestamp + moduleDelay; // NOTE: initially 2 weeks
        emit ModuleAdded(_newModule);
    }

    /// @notice deprecates new module from registry
    /// @param _existingModule address of module to remove
    function deprecateModule(address _existingModule) external override onlyPHOGovernance {
        Module storage module = modules[_existingModule];

        if (_existingModule == address(0)) revert ZeroAddress();
        if (module.status != Status.Registered) {
            revert UnregisteredModule(_existingModule);
        }
        /// NOTE - not sure if we need to make sure _existingModule has no minted PHO outstanding
        module.status = Status.Deprecated;
        module.phoCeiling = 0;
        emit ModuleDeprecated(_existingModule);
    }

    /// @notice sets new PHO ceiling for specified module
    /// @param _module address of module update
    /// @param _newPHOCeiling new PHO ceiling amount for module
    function setPHOCeilingForModule(address _module, uint256 _newPHOCeiling)
        external
        override
        onlyTONGovernance
    {
        Module memory module = modules[_module];
        if (_module == address(0)) revert ZeroAddress();
        if (module.status == Status.Unregistered) revert UnregisteredModule(_module);
        if (module.status == Status.Deprecated) revert DeprecatedModule(_module);
        // TODO - Commented out until kernel has PHOCeiling and totalPHOMinted uncommented
        // if (
        //     kernel.PHOCeiling()
        //         < (kernel.totalPHOMinted() + _newPHOCeiling - module.phoCeiling)
        // ) {
        //     revert KernalCeilingExceeded();
        // }
        modules[_module].phoCeiling = _newPHOCeiling;
        emit PHOCeilingUpdated(_module, _newPHOCeiling);
    }

    /// @notice set module delay
    /// @param _newDelay proposed delay before a newly deployed && registered module is functional
    function setModuleDelay(uint256 _newDelay) external override onlyPHOGovernance {
        if (_newDelay == 0) revert ZeroValue();
        moduleDelay = _newDelay;
        emit UpdatedModuleDelay(moduleDelay);
    }
}
