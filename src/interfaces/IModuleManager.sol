// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

interface IModuleManager {
    /// errors
    error ZeroAddress();
    error ZeroValue();
    error ModuleCeilingExceeded();
    error KernalCeilingExceeded();
    error ModuleBurningTooMuchPHO();
    error NotPHOGovernance(address caller);
    error NotTONGovernance(address caller);
    error NotRegisteredModule(address module);
    error AlreadyRegisteredModule();
    error KernelAlreadySet(address kernel);
    error DeprecatedModule(address module);

    /// events

    event ModuleAdded(address indexed module);
    event ModuleRemoved(address indexed module);
    event PHOCeilingUpdated(address indexed module, uint256 newPHOCeiling);
    event UpdatedModuleDelay(uint256 newDelay);
    event ModuleMint(address indexed module, uint256 amount);
    event ModuleBurn(address indexed module, uint256 amount);

    enum Status {
        Unregistered,
        Registered,
        Deprecated
    }

    struct Module {
        uint256 phoCeiling;
        uint256 phoMinted;
        uint256 startTime;
        Status status;
    }

    function mintPHO(uint256 _amount) external; // onlyModule
    function burnPHO(uint256 _amount) external; // onlyModule
    function addModule(address _newModule) external; // onlyPHOGovernance
    function removeModule(address _existingModule) external; // onlyPHOGovernance
    function setPHOCeilingForModule(address _module, uint256 _newPHOCeiling) external; // onlyTONGovernance
    function setModuleDelay(uint256 _newDelay) external; // onlyPHOGovernance
}
