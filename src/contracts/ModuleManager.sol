// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IPHO.sol";
import "../interfaces/IModuleManager.sol";
import "../interfaces/IPhotonKernel.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @title ModuleManager
/// @notice Intermediary btw Modules and PHOTONKernel
/// @author Ekonomia: https://github.com/Ekonomia

contract ModuleManager is IModuleManager, Ownable, ReentrancyGuard {
    IPhotonKernel kernel;
    address public PHOGovernance;
    address public TONGovernance;

    struct Modules {
        bool registered;
        uint256 phoCeiling;
        uint256 phoMinted;
        uint256 moduleDelayTimestamp; // TODO - is there a delay btw when TON voters deem module can mint && when module can actually mint too?
    }

    mapping(address => Modules) public registeredModules;

    /// modifiers

    modifier onlyModule() {
        require(
            registeredModules[msg.sender].registered, "ModuleManager: only module can mint/burn PHO"
        );
        _;
    }

    modifier onlyKernel() {
        require(msg.sender == address(kernel), "ModuleManager: only kernel can edit MM");
        _;
    }

    modifier nonZero(uint256 _input) {
        require(_input > 0, "ModuleManager: amount != 0");
        _;
    }

    modifier onlyPHOGovernance() {
        require(
            msg.sender == PHOGovernance, "ModuleManager: only PHOGovernance can edit ModuleManager"
        );
        _;
    }

    modifier onlyTONGovernance() {
        require(
            msg.sender == TONGovernance, "ModuleManager: only TONGovernance can edit ModuleManager"
        );
        _;
    }

    // need kernel address to access it, and allow it to set things.
    constructor(address _photonKernel, address _PHOGovernance, address _TONGovernance) {
        require(
            _photonKernel != address(0) && _PHOGovernance != address(0)
                && _TONGovernance != address(0),
            "ModuleManager: zero address detected"
        );
        kernel = IPhotonKernel(_photonKernel);
        PHOGovernance = _PHOGovernance;
        TONGovernance = _TONGovernance;
    }

    /// @notice updates module accounting && mints PHO through PhotonKernel
    /// @param _amount total PHO to be minted
    function mintPHO(uint256 _amount) external override onlyModule nonReentrant {
        require(_amount != 0, "ModuleManager: mint amount != 0");
        Modules memory module = registeredModules[msg.sender];
        uint256 modulePHO = module.phoMinted;
        require(
            modulePHO + _amount <= module.phoCeiling, "ModuleManager: module pho ceiling reached"
        );
        registeredModules[msg.sender].phoMinted = modulePHO + _amount;
        kernel.mintPHO(msg.sender, _amount);
    }

    /// @notice updates module accounting && burns PHO through PhotonKernel
    /// @dev NOTE - assumes that PHO is being burnt from module calling burn
    /// @param _amount total PHO to be burned
    function burnPHO(uint256 _amount) external override onlyModule nonReentrant {
        require(_amount != 0, "ModuleManager: burn amount != 0");
        Modules memory module = registeredModules[msg.sender];
        uint256 modulePHO = module.phoMinted;
        require(modulePHO - _amount >= 0, "ModuleManager: modulePHO minimum unmet");
        kernel.burnPHO(msg.sender, _amount);
        registeredModules[msg.sender].phoMinted = modulePHO - _amount;
    }

    /// @notice adds new module to registry
    /// @param _newModule address of module to add
    function addModule(address _newModule) external override onlyPHOGovernance {
        require(
            !registeredModules[_newModule].registered, "ModuleManager: module already registered"
        );
        require(_newModule != address(0), "ModuleManage: zero address detected");
        registeredModules[_newModule].registered = true;
        registeredModules[_newModule].moduleDelayTimestamp = block.timestamp + kernel.moduleDelay(); // NOTE: initially 2 weeks
        // registeredModules[_newModule].moduleDelayTimestamp = block.timestamp + kernel.moduleDelay(); // NOTE: initially 2 weeks

        emit ModuleAdded(_newModule);
    }

    /// @notice removes new module from registry
    /// @param _existingModule address of module to remove
    function removeModule(address _existingModule) external override onlyPHOGovernance {
        require(
            registeredModules[_existingModule].registered, "ModuleManager: module not registered"
        );
        require(_existingModule != address(0), "ModuleManage: zero address detected");
        /// NOTE - not sure if we need to make sure _existingModule has no minted PHO outstanding
        delete registeredModules[_existingModule];
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
        Modules memory module = registeredModules[_module];
        require(module.registered, "ModuleManager: module not registered");
        require(_module != address(0), "ModuleManager: zero address detected");
        require(_newPHOCeiling != 0, "ModuleManager: new ceiling amount != 0");
        uint256 oldCeiling = module.phoCeiling;
        require(
            kernel.PHOCeiling() < (kernel.totalPHOMinted() - oldCeiling + _newPHOCeiling),
            "ModuleManager: kernel PHO ceiling exceeded"
        );
        registeredModules[_module].phoCeiling = _newPHOCeiling;
        emit ModulePHOCeilingUpdated(_module, _newPHOCeiling);
    }
}
