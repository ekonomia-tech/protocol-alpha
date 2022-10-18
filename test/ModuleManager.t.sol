// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import "./BaseSetup.t.sol";
import {PHO} from "../src/contracts/PHO.sol";
import "src/interfaces/IKernel.sol";
import {ModuleManager} from "../src/contracts/ModuleManager.sol";

/// @notice Basic tests assessing ModuleManager.sol
contract ModuleManagerTest is BaseSetup {
    /// errors

    error ZeroAddressDetected();
    error ZeroValueDetected();
    error MaxModulePHOCeilingExceeded();
    error MaxKernelPHOCeilingExceeded();
    error Unauthorized_ModuleBurningTooMuchPHO();
    error Unauthorized_NotPHOGovernance(address caller);
    error Unauthorized_NotTONGovernance(address caller);
    error Unauthorized_NotRegisteredModule(address caller);
    error Unauthorized_AlreadyRegisteredModule();
    error KernelAlreadySet(address kernel);

    /// events

    event Transfer(address indexed from, address indexed to, uint256 value);

    event ModuleAdded(address indexed module);
    event ModuleRemoved(address indexed module);
    event PHOCeilingUpdated(address indexed module, uint256 newPHOCeiling);
    event UpdatedModuleDelay(uint256 newDelay, uint256 oldDelay);
    event Minted(address module, uint256 amount);
    event Burned(address module, uint256 amount);
    event KernelSet(address indexed kernel);

    struct Module {
        uint256 phoCeiling;
        uint256 phoMinted;
        uint256 startTime;
        Status status;
    }

    enum Status {
        Unregistered,
        Registered,
        Deprecated
    }

    function setUp() public {
        vm.startPrank(owner);
        // pho.setTeller(address(kernel));
        vm.stopPrank();

        vm.prank(PHOGovernance);
        moduleManager.addModule(owner);

        (,, uint256 startTime, ModuleManager.Status status) = moduleManager.modules(owner);
        assertEq(uint8(status), uint8(Status.Registered));
        assertEq(startTime, block.timestamp + moduleManager.moduleDelay());
        vm.prank(TONGovernance);
        moduleManager.setPHOCeilingForModule(owner, ONE_MILLION_D18);
        (uint256 newPhoCeiling,,,) = moduleManager.modules(owner);
        assertEq(newPhoCeiling, ONE_MILLION_D18);
    }

    function testModuleManagerConstructor() public {
        IKernel kernelCheck = moduleManager.kernel();
        assertEq(address(kernelCheck), address(kernel));
        assertEq(moduleManager.PHOGovernance(), PHOGovernance);
        assertEq(moduleManager.TONGovernance(), TONGovernance);
    }

    /// mintPHO() tests

    /// @notice non-registered addresses cannot mint through ModuleManager
    function testCannotMintPHOUnregistered() public {
        vm.startPrank(dummyAddress);
        vm.expectRevert(
            abi.encodeWithSelector(Unauthorized_NotRegisteredModule.selector, dummyAddress)
        );
        moduleManager.mintPHO(ONE_MILLION_D18);
        vm.stopPrank();
    }

    function testCannotMintPHOCeilingMax() public {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(MaxModulePHOCeilingExceeded.selector));
        moduleManager.mintPHO(ONE_MILLION_D18 * 2);
        vm.stopPrank();
    }

    function testMintPHO() public {
        vm.startPrank(owner);
        assertEq(pho.balanceOf(owner), 0);
        (, uint256 phoMinted,,) = moduleManager.modules(owner);
        assertEq(phoMinted, 0);
        vm.expectEmit(true, false, false, true);
        emit Transfer(address(0), owner, ONE_HUNDRED_THOUSAND_D18);
        emit Minted(owner, ONE_HUNDRED_THOUSAND_D18);
        moduleManager.mintPHO(ONE_HUNDRED_THOUSAND_D18);
        (, uint256 newPhoMinted,,) = moduleManager.modules(owner);
        assertEq(pho.balanceOf(owner), ONE_HUNDRED_THOUSAND_D18);
        assertEq(newPhoMinted, ONE_HUNDRED_THOUSAND_D18);
        vm.stopPrank();
    }

    /// @notice test multiple consecutive minting
    function testMultipleMintPHO() public {
        _moduleMintPHO();
        vm.startPrank(owner);
        moduleManager.mintPHO(TEN_THOUSAND_D18);
        moduleManager.mintPHO(ONE_HUNDRED_D18);

        (, uint256 newPhoMinted,,) = moduleManager.modules(owner);
        uint256 sum = ONE_HUNDRED_THOUSAND_D18 + TEN_THOUSAND_D18 + ONE_HUNDRED_D18;
        assertEq(pho.balanceOf(owner), sum);
        assertEq(newPhoMinted, sum);
        vm.stopPrank();
    }

    /// burnPHO() tests

    /// @notice non-registered addresses cannot burn through ModuleManager
    function testCannotBurnPHOUnregistered() public {
        vm.startPrank(dummyAddress);
        vm.expectRevert(
            abi.encodeWithSelector(Unauthorized_NotRegisteredModule.selector, dummyAddress)
        );
        moduleManager.burnPHO(ONE_HUNDRED_THOUSAND_D18);
        vm.stopPrank();
    }

    /// @notice burn amount cannot be zero
    function testCannotBurnZeroPHO() public {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(ZeroValueDetected.selector));
        moduleManager.burnPHO(0);
        vm.stopPrank();
    }

    function testCannotBurnPastZero() public {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized_ModuleBurningTooMuchPHO.selector));
        moduleManager.burnPHO(ONE_MILLION_D18 * 2);
        vm.stopPrank();
    }

    function testBurnPHO() public {
        _moduleMintPHO();
        uint256 expectedModulePHO = TEN_THOUSAND_D18 * 5;
        vm.startPrank(owner);
        assertEq(pho.balanceOf(owner), ONE_HUNDRED_THOUSAND_D18);

        (, uint256 phoMinted,,) = moduleManager.modules(owner);

        assertEq(phoMinted, ONE_HUNDRED_THOUSAND_D18);
        pho.approve(address(kernel), pho.balanceOf(owner));
        vm.expectEmit(true, false, false, true);
        emit Transfer(owner, address(0), TEN_THOUSAND_D18 * 5);
        emit Burned(owner, TEN_THOUSAND_D18 * 5);
        moduleManager.burnPHO(TEN_THOUSAND_D18 * 5);
        assertEq(pho.balanceOf(owner), expectedModulePHO);

        (, uint256 newPhoMinted,,) = moduleManager.modules(owner);

        assertEq(newPhoMinted, expectedModulePHO);
        vm.stopPrank();
    }

    function testMultipleBurnPHO() public {
        _moduleMintPHO();
        uint256 expectedModulePHO = TEN_THOUSAND_D18 * 3;
        vm.startPrank(owner);
        pho.approve(address(kernel), pho.balanceOf(owner));
        moduleManager.burnPHO(TEN_THOUSAND_D18 * 5);
        moduleManager.burnPHO(TEN_THOUSAND_D18);
        moduleManager.burnPHO(TEN_THOUSAND_D18);
        assertEq(pho.balanceOf(owner), expectedModulePHO);
        (, uint256 phoMinted,,) = moduleManager.modules(owner);

        assertEq(phoMinted, expectedModulePHO);
        vm.stopPrank();
    }

    /// addModule() tests

    function testCannotAddRegisteredModule() public {
        vm.startPrank(PHOGovernance);
        (,,, ModuleManager.Status status) = moduleManager.modules(owner);
        assertEq(uint8(status), uint8(Status.Registered));

        vm.expectRevert(abi.encodeWithSelector(Unauthorized_AlreadyRegisteredModule.selector));
        moduleManager.addModule(owner);
        (,,, ModuleManager.Status newStatus) = moduleManager.modules(owner);
        assertEq(uint8(newStatus), uint8(Status.Registered)); // check that status hasn't changed
        vm.stopPrank();
    }

    function testCannotAddZeroAddress() public {
        vm.startPrank(PHOGovernance);
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        moduleManager.addModule(address(0));
        vm.stopPrank();
    }

    function testCannotAddModuleNonPHOGovernance() public {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized_NotPHOGovernance.selector, owner));
        moduleManager.addModule(owner);
        vm.stopPrank();
    }

    function testAddModule() public {
        vm.startPrank(PHOGovernance);

        (,,, ModuleManager.Status status) = moduleManager.modules(user1);
        assertEq(uint8(status), uint8(Status.Unregistered));

        vm.expectEmit(true, false, false, true);
        emit ModuleAdded(user1);
        moduleManager.addModule(user1);

        (,, uint256 newStartTime, ModuleManager.Status newStatus) = moduleManager.modules(user1);
        assertEq(uint8(newStatus), uint8(Status.Registered));
        assertEq(newStartTime, block.timestamp + moduleManager.moduleDelay());
        vm.stopPrank();
    }

    /// removeModule() tests

    function testCannotRemoveUnRegisteredModule() public {
        vm.startPrank(PHOGovernance);

        (,,, ModuleManager.Status status) = moduleManager.modules(user1);
        assertEq(uint8(status), uint8(Status.Unregistered));

        vm.expectRevert(abi.encodeWithSelector(Unauthorized_NotRegisteredModule.selector, user1));
        moduleManager.removeModule(user1);
        (,,, ModuleManager.Status newStatus) = moduleManager.modules(user1);
        assertEq(uint8(newStatus), uint8(Status.Unregistered)); // check that status hasn't changed
        vm.stopPrank();
    }

    function testCannotRemoveZeroAddress() public {
        vm.startPrank(PHOGovernance);
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        moduleManager.removeModule(address(0));
        vm.stopPrank();
    }

    function testCannotRemoveModuleNonPHOGovernance() public {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized_NotPHOGovernance.selector, owner));
        moduleManager.removeModule(owner);
        vm.stopPrank();
    }

    function testRemoveModule() public {
        vm.startPrank(PHOGovernance);

        (,,, ModuleManager.Status status) = moduleManager.modules(owner);
        assertEq(uint8(status), uint8(Status.Registered));

        vm.expectEmit(true, false, false, true);
        emit ModuleRemoved(owner);
        moduleManager.removeModule(owner);

        (uint256 newPhoCeiling,,, ModuleManager.Status newStatus) = moduleManager.modules(owner);
        assertEq(uint8(newStatus), uint8(Status.Deprecated));

        // TODO - do we need an endTime for modules when they are deprecated?
        assertEq(newPhoCeiling, 0);
        vm.stopPrank();
    }

    /// setPHOCeilingModule() tests
    /// NOTE - PHOCeilingModule() tests

    function testCannotSetPHOCeilingUnregistered() public {
        vm.startPrank(TONGovernance);
        vm.expectRevert(
            abi.encodeWithSelector(Unauthorized_NotRegisteredModule.selector, dummyAddress)
        );
        moduleManager.setPHOCeilingForModule(dummyAddress, ONE_MILLION_D18);
        vm.stopPrank();
    }

    function testCannotSetPHOCeilingZeroAddress() public {
        vm.startPrank(TONGovernance);
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        moduleManager.setPHOCeilingForModule(address(0), 0);
        vm.stopPrank();
    }

    // /// TODO - this test requires kernel.PHOCeiling() to be set
    // function testCannotSetPHOCeilingMaxExceeded() public {
    //     vm.startPrank(TONGovernance);
    //     vm.expectRevert(abi.encodeWithSelector(MaxKernelPHOCeilingExceeded.selector);
    //     moduleManager.setPHOCeilingForModule(owner, kernel.PHOCeiling() + 1);
    //     vm.stopPrank();
    // }

    function testCannotSetPHOCeilingNonTONGovernance() public {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized_NotTONGovernance.selector, owner));
        moduleManager.setPHOCeilingForModule(owner, ONE_MILLION_D18 * 10);
        vm.stopPrank();
    }

    function testSetPHOCeilingModule() public {
        uint256 expectedPHOCeiling = ONE_MILLION_D18 * 10;
        vm.startPrank(TONGovernance);
        vm.expectEmit(true, false, false, true);
        emit PHOCeilingUpdated(owner, expectedPHOCeiling);
        moduleManager.setPHOCeilingForModule(owner, ONE_MILLION_D18 * 10);

        (uint256 phoCeiling,,,) = moduleManager.modules(owner);

        assertEq(phoCeiling, expectedPHOCeiling);
        vm.stopPrank();
    }

    function testCannotSetModuleDelay() public {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(ZeroValueDetected.selector));
        moduleManager.setModuleDelay(0);
        vm.stopPrank();
    }

    function testCannotSetModuleDelayOnlyOwner() public {
        vm.startPrank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        moduleManager.setModuleDelay(0);
        vm.stopPrank();
    }

    function testSetModuleDelay() public {
        vm.startPrank(owner);
        vm.expectEmit(false, false, false, true);
        emit UpdatedModuleDelay(3 weeks, 2 weeks);
        moduleManager.setModuleDelay(3 weeks);
        assertEq(moduleManager.moduleDelay(), 3 weeks);
        vm.stopPrank();
    }

    function testCannotSetKernelOnlyOwner() public {
        vm.startPrank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        moduleManager.setKernel(dummyAddress);
        vm.stopPrank();
    }

    function testCannotSetKernelAddressZero() public {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        moduleManager.setKernel(address(0));
        vm.stopPrank();
    }

    function testCannotResetKernel() public {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(KernelAlreadySet.selector, address(kernel)));
        moduleManager.setKernel(dummyAddress);
        vm.stopPrank();
    }

    function testSetKernel() public {
        vm.startPrank(owner);
        ModuleManager moduleManager2 = new ModuleManager(PHOGovernance, TONGovernance);
        vm.expectEmit(true, false, false, true);
        emit KernelSet(address(kernel));
        moduleManager2.setKernel(address(kernel));
        vm.stopPrank();
    }

    /// helpers

    /// @notice helper function to mint 100k PHO to owner module
    function _moduleMintPHO() internal {
        vm.startPrank(owner);
        moduleManager.mintPHO(ONE_HUNDRED_THOUSAND_D18);
        vm.stopPrank();
    }
}
