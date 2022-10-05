// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

interface IModuleManager {
    /// events

    event ModuleAdded(address indexed module);
    event ModuleRemoved(address indexed module);
    event PHOCeilingUpdated(address indexed module, uint256 newPHOCeiling);

    function mintPHO(uint256 _amount) external; // onlyModule
    function burnPHO(uint256 _amount) external; // onlyModule
    function addModule(address _newModule) external; // onlyPHOGovernance
    function removeModule(address _existingModule) external; // onlyPHOGovernance
    function setPHOCeilingForModule(address _module, uint256 _newPHOCeiling) external; // onlyTONGovernance
}
