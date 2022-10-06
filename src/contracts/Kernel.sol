// SPDX-License-Identifier: GPL-3.0-or-later

import "../interfaces/IKernel.sol";
import "../interfaces/IPHO.sol";
import "../interfaces/IDispatcher.sol";

contract Kernel is IKernel {
    IPHO public pho;

    uint256 PHOCeiling;
    uint256 totalPHOMinted;
    uint256 moduleManagerDelay = 4 weeks;
    uint256 dispatcherDelay = 4 weeks;
    uint256 moduleDelay = 2 weeks;

    IDispatcher dispatcher;
    address moduleManager;
    address TONGovernance;

    modifier onlyModuleManager() {
        if (msg.sender != moduleManager) revert Unauthorized_NotModuleManager(msg.sender);
        _;
    }

    modifier onlyTONGovernance() {
        if (msg.sender != TONGovernance) revert Unauthorized_NotTONGovernance(msg.sender);
        _;
    }

    constructor(
        address _pho,
        address _moduleManager,
        address _dispatcher,
        address _TONGovernance,
        uint256 _PHOCeiling
    ) {
        pho = IPHO(_pho);
        moduleManager = _moduleManager;
        dispatcher = IDispatcher(_dispatcher);
        TONGovernance = _TONGovernance;
        PHOCeiling = _PHOCeiling;
    }

    function mintPHO(address to, uint256 amount) external onlyModuleManager {
        if (to == address(0)) revert ZeroAddressDetected();
        if (amount == 0) revert ZeroValueDetected();
        if (totalPHOMinted + amount > PHOCeiling) {
            revert MintingCeilingReached(PHOCeiling, totalPHOMinted, amount);
        }
        totalPHOMinted += amount;
        pho.mint(to, amount);
    }

    function burnPHO(address from, uint256 amount) external onlyModuleManager {
        if (from == address(0)) revert ZeroAddressDetected();
        if (amount == 0) revert ZeroValueDetected();
        totalPHOMinted -= amount;
        pho.burnFrom(from, amount);
    }

    function setPHOCeiling(uint256 newCeiling) external onlyTONGovernance {
        if (newCeiling < totalPHOMinted) {
            revert CeilingLowerThanTotalMinted(totalPHOMinted, PHOCeiling);
        }
        PHOCeiling = newCeiling;
        emit PHOCeilingUpdated(newCeiling);
    }

    function updateModuleManagerDelay(uint256 newDelay) external onlyTONGovernance {
        if (newDelay == 0) revert ZeroValueDetected();
        moduleManagerDelay = newDelay;
        emit ModuleManagerDelayUpdated(newDelay);
    }

    function updateDispatcherDelay(uint256 newDelay) external onlyTONGovernance {
        if (newDelay == 0) revert ZeroValueDetected();
        dispatcherDelay = newDelay;
        emit DispatcherDelayUpdated(newDelay);
    }

    function addModuleDelay(uint256 newDelay) external onlyTONGovernance {
        if (newDelay == 0) revert ZeroValueDetected();
        moduleDelay = newDelay;
        emit ModuleDelayUpdated(newDelay);
    }

    function updateDispatcher(address newDispatcher) external onlyTONGovernance {
        if (newDispatcher == address(0)) revert ZeroAddressDetected();
        if (newDispatcher == address(dispatcher)) revert SameAddressDetected();
        dispatcher = IDispatcher(newDispatcher);
        emit DispatcherUpdated(newDispatcher);
    }

    function updateModuleManager(address newModuleManager) external onlyTONGovernance {
        if (newModuleManager == address(0)) revert ZeroAddressDetected();
        if (newModuleManager == moduleManager) revert SameAddressDetected();
        moduleManager = newModuleManager;
        emit ModuleManagerUpdated(newModuleManager);
    }
}
