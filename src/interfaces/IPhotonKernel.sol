// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

interface IPHOTONKernel {
    function mintPHO(address to, uint256 amount) external; // onlyModuleManager
    function burnPHO(address to, uint256 amount) external; // onlyModuleManager

    // global state
    function setPHOCeiling() external; // onlyTONGovernance
    function updateModuleManagerDelay() external; // 4 weeks. Rarely happens
    function updateDispatcherDelay() external; // 4 weeks. Rarely happens
    function addModuleDelay() external; // 2 weeks. For safe exit of angry people

    // managers
    function updateDispatcher() external; // onlyTONGovernance
    function updateModuleManager() external; // onlyTONGovernance

    function getPHOCeiling() external view returns (uint256);
    function getTotalPHOMinted() external view returns (uint256);

    // governance - NOTE - commented out for now. Let's use basic governance
    // function setTONGovernanceContract() external; // onlyTONGovernance
    // function setPHOGovernanceContract() external; // onlyTONGovernance
}
