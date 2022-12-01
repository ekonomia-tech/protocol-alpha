// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

interface IModuleManager {
    /// errors
    error ZeroAddress();
    error SameAddress();
    error ZeroValue();
    error SameValue();
    error ModuleCeilingExceeded();
    error KernelCeilingExceeded();
    error ModuleBurnExceeded();
    error NotTimelock();
    error NotPHOGovernance(address caller);
    error NotTONGovernance(address caller);
    error ModuleUnavailable(address module, Status status);
    error ModuleRegistered();
    error UnregisteredModule();
    error ModuleNotPaused();
    error DelayNotMet();
    error UpdateNotAvailable();
    error NotPauseGuardian();

    /// events

    event ModuleAdded(address indexed module);
    event ModuleDeprecated(address indexed module);
    event PHOCeilingUpdateScheduled(
        address indexed module, uint256 upcomingCeiling, uint256 ceilingUpdateTime
    );
    event UpdatedModuleDelay(uint256 newDelay);
    event ModuleMint(address indexed module, address indexed to, uint256 amount);
    event ModuleBurn(address indexed module, address indexed from, uint256 amount);
    event ModulePaused(address indexed module);
    event ModuleUnpaused(address indexed module);
    event PHOCeilingUpdated(address indexed module, uint256 newPHOCeiling);
    event PauseGuardianUpdated(address newPauseGuardian);

    enum Status {
        Unregistered,
        Active,
        Paused,
        Deprecated
    }

    struct Module {
        uint256 phoCeiling;
        uint256 upcomingCeiling;
        uint256 ceilingUpdateTime;
        uint256 phoMinted;
        uint256 startTime;
        Status status;
    }

    function mintPHO(address to, uint256 _amount) external;
    function burnPHO(address from, uint256 _amount) external;
    function addModule(address _newModule) external;
    function deprecateModule(address _existingModule) external;
    function setPHOCeilingForModule(address _module, uint256 _newPHOCeiling) external;
    function setModuleDelay(uint256 _newDelay) external;
    function pauseModule(address _module) external;
    function unpauseModule(address _module) external;
    function setPauseGuardian(address _pauseGuardian) external;
    function executeCeilingUpdate(address _module) external;
}
