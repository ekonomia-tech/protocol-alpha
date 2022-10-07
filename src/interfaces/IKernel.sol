// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IKernel {
    error ZeroAddressDetected();
    error ZeroValueDetected();
    error SameAddressDetected();
    error SameValueDetected();
    error Unauthorized_NotModuleManager(address caller);
    error Unauthorized_NotTONGovernance(address caller);

    event ModuleManagerDelayUpdated(uint256 newDelay);
    event DispatcherDelayUpdated(uint256 newDelay);
    event DispatcherUpdated(address indexed newDispatcher);
    event ModuleManagerUpdated(address indexed newModuleManager);

    function mintPHO(address to, uint256 amount) external; // onlyModuleManager
    function burnPHO(address from, uint256 amount) external; // onlyModuleManager
    function updateModuleManagerDelay(uint256 newDelay) external; // 4 weeks. Rarely happens
    function updateDispatcherDelay(uint256 newDelay) external; // 4 weeks. Rarely happens
    function updateDispatcher(address newDispatcher) external; // onlyTONGovernance
    function updateModuleManager(address newModuleManager) external; // onlyTONGovernance
}
