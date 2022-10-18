// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IPHO.sol";
import "../interfaces/IModuleManager.sol";
import "../interfaces/IKernel.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @title ModuleManager
/// @notice Intermediary between Modules and Kernel
/// @author Ekonomia: https://github.com/Ekonomia
contract ModuleManager is IModuleManager, Ownable, ReentrancyGuard {
    IKernel public kernel;
    address public PHOGovernance;
    address public TONGovernance;
    uint256 public moduleDelay;

    // TODO - Niv's questions: what are the status' of modules really? When we stop using a module, is it just deprecated? I think he was saying something like decomissioned. They mean the same thing to me. Registered means active. Unregistered means they were never active.
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

    mapping(address => Module) public modules;

    bool public kernelSet;

    /// modifiers

    modifier onlyModule() {
        if (modules[msg.sender].status != Status.Registered) {
            revert Unauthorized_NotRegisteredModule(msg.sender);
        }
        _;
    }

    modifier onlyPHOGovernance() {
        if (msg.sender != PHOGovernance) revert Unauthorized_NotPHOGovernance(msg.sender);
        _;
    }

    modifier onlyTONGovernance() {
        if (msg.sender != TONGovernance) revert Unauthorized_NotTONGovernance(msg.sender);
        _;
    }

    /// NOTE -  need to setKernel right after initial deployment of ModuleManager
    constructor(address _PHOGovernance, address _TONGovernance) {
        if (_PHOGovernance == address(0) || _TONGovernance == address(0)) {
            revert ZeroAddressDetected();
        }
        PHOGovernance = _PHOGovernance;
        TONGovernance = _TONGovernance;
        moduleDelay = 2 weeks;
    }

    /// @notice updates module accounting && mints PHO through Kernel
    /// @param _amount total PHO to be minted
    function mintPHO(uint256 _amount) external override onlyModule nonReentrant {
        require(_amount != 0, "Mint amount != 0");
        if (_amount == 0) revert ZeroValueDetected();
        Module memory module = modules[msg.sender];
        if (module.phoMinted + _amount > module.phoCeiling) revert MaxModulePHOCeilingExceeded();
        modules[msg.sender].phoMinted = module.phoMinted + _amount;
        kernel.mintPHO(msg.sender, _amount);
        emit Minted(msg.sender, _amount);
    }

    /// @notice updates module accounting && burns PHO through Kernel
    /// @dev NOTE - assumes that PHO is being burnt from module calling burn
    /// @param _amount total PHO to be burned
    function burnPHO(uint256 _amount) external override onlyModule nonReentrant {
        if (_amount == 0) revert ZeroValueDetected();
        Module memory module = modules[msg.sender];
        if ((module.phoMinted <= _amount)) revert Unauthorized_ModuleBurningTooMuchPHO();
        kernel.burnPHO(msg.sender, _amount);
        modules[msg.sender].phoMinted = module.phoMinted - _amount;
        emit Burned(msg.sender, _amount);
    }

    /// @notice adds new module to registry
    /// @param _newModule address of module to add
    function addModule(address _newModule) external override onlyPHOGovernance {
        if (_newModule == address(0)) revert ZeroAddressDetected();
        if (modules[_newModule].status == Status.Registered) {
            revert Unauthorized_AlreadyRegisteredModule();
        }
        modules[_newModule].status = Status.Registered;
        modules[_newModule].startTime = block.timestamp + moduleDelay; // NOTE: initially 2 weeks
        emit ModuleAdded(_newModule);
    }

    /// @notice removes new module from registry
    /// @param _existingModule address of module to remove
    function removeModule(address _existingModule) external override onlyPHOGovernance {
        if (_existingModule == address(0)) revert ZeroAddressDetected();
        if (modules[_existingModule].status != Status.Registered) {
            revert Unauthorized_NotRegisteredModule(_existingModule);
        }
        /// NOTE - not sure if we need to make sure _existingModule has no minted PHO outstanding
        modules[_existingModule].status = Status.Deprecated;
        modules[_existingModule].phoCeiling = 0;
        emit ModuleRemoved(_existingModule);
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
        if (_module == address(0)) revert ZeroAddressDetected();
        if (module.status != Status.Registered) revert Unauthorized_NotRegisteredModule(_module);
        // TODO - Commented out until kernel has PHOCeiling and totalPHOMinted uncommented
        // if (
        //     kernel.PHOCeiling()
        //         < (kernel.totalPHOMinted() + _newPHOCeiling - module.phoCeiling)
        // ) {
        //     revert MaxKernelPHOCeilingExceeded();
        // }
        modules[_module].phoCeiling = _newPHOCeiling;
        emit PHOCeilingUpdated(_module, _newPHOCeiling);
    }

    /// @notice set module delay
    /// @param _newDelay proposed delay before a newly deployed && registered module is functional
    function setModuleDelay(uint256 _newDelay) external override onlyOwner {
        if (_newDelay == 0) revert ZeroValueDetected();
        uint256 oldModuleDelay = moduleDelay;
        moduleDelay = _newDelay;
        emit UpdatedModuleDelay(moduleDelay, oldModuleDelay);
    }

    /// @notice set kernel address
    /// @param _kernel Kernel address
    function setKernel(address _kernel) external override onlyOwner {
        if (_kernel == address(0)) revert ZeroAddressDetected();
        if (kernelSet) revert KernelAlreadySet(address(kernel));
        kernelSet = true;
        kernel = IKernel(_kernel);
        emit KernelSet(_kernel);
    }
}
