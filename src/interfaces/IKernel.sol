// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IKernel {
    error ZeroAddressDetected();
    error ZeroValueDetected();
    error SameAddressDetected();
    error SameValueDetected();
    error MintingCeilingReached(uint256 ceiling, uint256 totalPHOMinted, uint256 attemptedMint);
    error Unauthorized_NotModuleManager(address caller);
    error Unauthorized_NotTONGovernance(address caller);
    error CeilingLowerThanTotalMinted(uint256 totalPHOMinted, uint256 attemptedNewCeiling);

    event PHOCeilingUpdated(uint256 newCeiling);
    event ModuleManagerDelayUpdated(uint256 newDelay);
    event DispatcherDelayUpdated(uint256 newDelay);
    event ModuleDelayUpdated(uint256 newDelay);
    event DispatcherUpdated(address indexed newDispatcher);
    event ModuleManagerUpdated(address indexed newModuleManager);

    function mintPHO(address to, uint256 amount) external; // onlyModuleManager
    function burnPHO(address from, uint256 amount) external; // onlyModuleManager
    function setPHOCeiling(uint256 newCeiling) external; // onlyTONGovernance
    function updateModuleManagerDelay(uint256 newDelay) external; // 4 weeks. Rarely happens
    function updateDispatcherDelay(uint256 newDelay) external; // 4 weeks. Rarely happens
    function addModuleDelay(uint256 newDelay) external; // 2 weeks. For safe exit of angry people
    function updateDispatcher(address newDispatcher) external; // onlyTONGovernance
    function updateModuleManager(address newModuleManager) external; // onlyTONGovernance
}
