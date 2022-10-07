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

    /// @param _pho the $PHO contract address
    /// @param _moduleManager the address of the current module manager
    /// @param _dispatcher the address of the current deployed dispatcher
    /// @param _TONGovernance the governance address for $TON
    constructor(address _pho, address _moduleManager, address _dispatcher, address _TONGovernance) {
        pho = IPHO(_pho);
        moduleManager = _moduleManager;
        dispatcher = IDispatcher(_dispatcher);
        TONGovernance = _TONGovernance;
    }

    /// @notice function to mint $PHO that can be called only by moduleManager
    /// @param to the address to which $PHO will be minted to
    /// @param amount the amount of $PHO to be minted
    function mintPHO(address to, uint256 amount) external onlyModuleManager {
        if (to == address(0)) revert ZeroAddressDetected();
        if (amount == 0) revert ZeroValueDetected();
        pho.mint(to, amount);
    }

    /// @notice function to burn $PHO that cab be called only by moduleManager
    /// @param from the address to burn $PHO from
    /// @param amount the amount of $PHO to burn
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

    /// @notice function to update the module manager delay for updating a module manager
    /// @param newDelay the new delay in seconds
    function updateModuleManagerDelay(uint256 newDelay) external onlyTONGovernance {
        if (newDelay == 0) revert ZeroValueDetected();
        if (newDelay == moduleManagerDelay) revert SameValueDetected();
        moduleManagerDelay = newDelay;
        emit ModuleManagerDelayUpdated(newDelay);
    }

    /// @notice function to update the dispatcher delay for updating a dispatcher
    /// @param newDelay the new delay in seconds
    function updateDispatcherDelay(uint256 newDelay) external onlyTONGovernance {
        if (newDelay == 0) revert ZeroValueDetected();
        if (newDelay == dispatcherDelay) revert SameValueDetected();
        dispatcherDelay = newDelay;
        emit DispatcherDelayUpdated(newDelay);
    }

    /// @notice update the dispatcher address in the kernel
    /// @param newDispatcher the new dispatcher address
    function updateDispatcher(address newDispatcher) external onlyTONGovernance {
        if (newDispatcher == address(0)) revert ZeroAddressDetected();
        if (newDispatcher == address(dispatcher)) revert SameAddressDetected();
        dispatcher = IDispatcher(newDispatcher);
        emit DispatcherUpdated(newDispatcher);
    }

    /// @notice update the module manager address in the kernel
    /// @param newModuleManager the new module manager address
    function updateModuleManager(address newModuleManager) external onlyTONGovernance {
        if (newModuleManager == address(0)) revert ZeroAddressDetected();
        if (newModuleManager == moduleManager) revert SameAddressDetected();
        moduleManager = newModuleManager;
        emit ModuleManagerUpdated(newModuleManager);
    }
}
