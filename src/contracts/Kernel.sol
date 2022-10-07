// SPDX-License-Identifier: GPL-3.0-or-later

import "../interfaces/IKernel.sol";
import "../interfaces/IPHO.sol";
import "../interfaces/IDispatcher.sol";

contract Kernel is IKernel {
    IPHO public pho;

    // uint256 PHOCeiling;
    // uint256 totalPHOMinted;
    uint256 public moduleManagerDelay = 4 weeks;
    uint256 public dispatcherDelay = 4 weeks;
    uint256 public moduleDelay = 2 weeks;

    IDispatcher public dispatcher;
    address public moduleManager;
    address public TONGovernance;

    modifier onlyModuleManager() {
        if (msg.sender != moduleManager) revert Unauthorized_NotModuleManager(msg.sender);
        _;
    }

    modifier onlyTONGovernance() {
        if (msg.sender != TONGovernance) revert Unauthorized_NotTONGovernance(msg.sender);
        _;
    }

    constructor(address _pho, address _moduleManager, address _dispatcher, address _TONGovernance) {
        pho = IPHO(_pho);
        moduleManager = _moduleManager;
        dispatcher = IDispatcher(_dispatcher);
        TONGovernance = _TONGovernance;
    }

    function mintPHO(address to, uint256 amount) external onlyModuleManager {
        if (to == address(0)) revert ZeroAddressDetected();
        if (amount == 0) revert ZeroValueDetected();
        pho.mint(to, amount);
    }

    function burnPHO(address from, uint256 amount) external onlyModuleManager {
        if (from == address(0)) revert ZeroAddressDetected();
        if (amount == 0) revert ZeroValueDetected();
        pho.burnFrom(from, amount);
    }

    // function setPHOCeiling(uint256 newCeiling) external onlyTONGovernance {
    //     if (newCeiling < totalPHOMinted) {
    //         revert CeilingLowerThanTotalMinted(totalPHOMinted, PHOCeiling);
    //     }
    //     PHOCeiling = newCeiling;
    //     emit PHOCeilingUpdated(newCeiling);
    // }

    function updateModuleManagerDelay(uint256 newDelay) external onlyTONGovernance {
        if (newDelay == 0) revert ZeroValueDetected();
        if (newDelay == moduleManagerDelay) revert SameValueDetected();
        moduleManagerDelay = newDelay;
        emit ModuleManagerDelayUpdated(newDelay);
    }

    function updateDispatcherDelay(uint256 newDelay) external onlyTONGovernance {
        if (newDelay == 0) revert ZeroValueDetected();
        if (newDelay == dispatcherDelay) revert SameValueDetected();
        dispatcherDelay = newDelay;
        emit DispatcherDelayUpdated(newDelay);
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
