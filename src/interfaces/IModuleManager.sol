// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

interface IModuleManager {
    /// errors
    error ZeroAddressDetected();
    error ZeroValueDetected();
    error MaxModulePHOCeilingExceeded();
    error MaxKernelPHOCeilingExceeded();
    error Unauthorized_ModuleBurningTooMuchPHO();
    error Unauthorized_NotPHOGovernance(address caller);
    error Unauthorized_NotTONGovernance(address caller);
    error Unauthorized_NotRegisteredModule(address caller);
    error Unauthorized_AlreadyRegisteredModule();

    /// events

    event ModuleAdded(address indexed module);
    event ModuleRemoved(address indexed module);
    event PHOCeilingUpdated(address indexed module, uint256 newPHOCeiling);
    event UpdatedModuleDelay(uint256 newDelay, uint256 oldDelay);
    event Minted(address indexed module, uint256 amount);
    event Burned(address indexed module, uint256 amount);

    function mintPHO(uint256 _amount) external; // onlyModule
    function burnPHO(uint256 _amount) external; // onlyModule
    function addModule(address _newModule) external; // onlyPHOGovernance
    function removeModule(address _existingModule) external; // onlyPHOGovernance
    function setPHOCeilingForModule(address _module, uint256 _newPHOCeiling) external; // onlyTONGovernance
    function setModuleDelay(uint256 _newDelay) external;
}
