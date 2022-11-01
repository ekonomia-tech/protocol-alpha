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

    modifier onlyActiveModule() {
        _checkModuleStatus(msg.sender);
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
    function mintPHO(address _to, uint256 _amount) external onlyActiveModule {
        if (_amount == 0) revert ZeroValue();
        Module storage module = modules[msg.sender];
        if (module.phoMinted + _amount > module.phoCeiling) {
            revert ModuleCeilingExceeded();
        }
        module.phoMinted = module.phoMinted + _amount;
        kernel.mintPHO(_to, _amount);
        emit ModuleMint(msg.sender, _to, _amount);
    }

    /// @notice updates module accounting && burns PHO through Kernel
    /// @param _from the user that $PHO will be burned from
    /// @param _amount total PHO to be burned
    function burnPHO(address _from, uint256 _amount) external {
        if (_amount == 0) revert ZeroValue();
        Module storage module = modules[msg.sender];
        if (module.status == Status.Unregistered) revert UnregisteredModule();
        if ((module.phoMinted < _amount)) revert ModuleBurnExceeded();
        kernel.burnPHO(_from, _amount);
        module.phoMinted = module.phoMinted - _amount;
        emit ModuleBurn(msg.sender, _from, _amount);
    }

    /// @notice adds new module to registry
    /// @param _newModule address of module to add
    function addModule(address _newModule) external onlyPHOGovernance {
        if (_newModule == address(0)) revert ZeroAddress();
        Module storage module = modules[_newModule];
        if (module.status != Status.Unregistered) revert ModuleRegistered();
        module.status = Status.Active;
        module.startTime = block.timestamp + moduleDelay;
        emit ModuleAdded(_newModule);
    }

    /// @notice deprecates new module from registry
    /// @param _existingModule address of module to remove
    function deprecateModule(address _existingModule) external onlyPHOGovernance {
        if (_existingModule == address(0)) revert ZeroAddress();
        Module storage module = modules[_existingModule];
        if (module.status == Status.Unregistered) revert UnregisteredModule();
        module.status = Status.Deprecated;
        module.phoCeiling = 0;
        emit ModuleDeprecated(_existingModule);
    }

    /// @notice sets new PHO ceiling for specified module
    /// @param _module address of module update
    /// @param _newPHOCeiling new PHO ceiling amount for module
    function setPHOCeilingForModule(address _module, uint256 _newPHOCeiling)
        external
        onlyTONGovernance
    {
        if (_module == address(0)) revert ZeroAddress();
        _checkModuleStatus(_module);
        Module storage module = modules[_module];
        if (module.phoCeiling == _newPHOCeiling) revert SameValue();
        module.upcomingCeiling = _newPHOCeiling;
        module.upcomingUpdate = block.timestamp + moduleDelay;
        emit PHOCeilingUpdateScheduled(_module, _newPHOCeiling, module.upcomingUpdate);
    }

    /// @notice executes the PHO ceiling update scheduled by setPHOCeilingForModule()
    /// @param _module address of module update
    function executeCeilingUpdate(address _module) external {
        if (_module == address(0)) revert ZeroAddress();
        _checkModuleStatus(_module);
        Module storage module = modules[_module];
        if (module.upcomingCeiling == 0 || module.upcomingUpdate == 0) revert UpdateNotAvailable();
        if (module.upcomingUpdate > block.timestamp) revert DelayNotMet();
        module.phoCeiling = module.upcomingCeiling;
        module.upcomingCeiling = 0;
        module.upcomingUpdate = 0;
        emit PHOCeilingUpdated(_module, module.phoCeiling);
    }

    /// @notice set module delay
    /// @param _newDelay proposed delay before a newly deployed && registered module is functional
    function setModuleDelay(uint256 _newDelay) external onlyPHOGovernance {
        if (_newDelay == 0) revert ZeroValue();
        moduleDelay = _newDelay;
        emit UpdatedModuleDelay(moduleDelay);
    }

    /// @notice pause a module
    /// @param _module the module to be paused
    function pauseModule(address _module) external onlyTONGovernance {
        if (_module == address(0)) revert ZeroAddress();
        _checkModuleStatus(_module);
        Module storage module = modules[_module];
        module.status = Status.Paused;
        emit ModulePaused(_module);
    }

    /// @notice unpause module
    /// @param _module the module to be unpaused
    function unpauseModule(address _module) external onlyTONGovernance {
        if (_module == address(0)) revert ZeroAddress();
        Module storage module = modules[_module];
        if (module.status != Status.Paused) revert ModuleNotPaused();
        module.status = Status.Active;
        emit ModuleUnpaused(_module);
    }

    function _checkModuleStatus(address _module) private view {
        Module memory module = modules[_module];
        if (module.status != Status.Active) {
            revert ModuleUnavailable(_module, module.status);
        }
    }
}
