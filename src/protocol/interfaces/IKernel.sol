// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IKernel {
    error ZeroAddress();
    error ZeroValue();
    error SameAddress();
    error SameValue();
    error NotModuleManager(address caller);
    error NotTONTimelock();

    event ModuleManagerDelayUpdated(uint256 newDelay);
    event ModuleManagerUpdated(address indexed newModuleManager);

    function mintPHO(address to, uint256 amount) external; // onlyModuleManager
    function burnPHO(address from, uint256 amount) external; // onlyModuleManager
    function updateModuleManagerDelay(uint256 newDelay) external; // 4 weeks. Rarely happens
    function updateModuleManager(address newModuleManager) external; // onlyTONGovernance
}
