// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import "./BaseSetup.t.sol";
import {PHO} from "../src/contracts/PHO.sol";
import "src/interfaces/IKernel.sol";
import {ModuleManager} from "../src/contracts/ModuleManager.sol";

/// @notice Basic tests assessing ModuleManager.sol
contract ModuleManagerTest is BaseSetup {
    /// errors

    error ZeroAddress();
    error ZeroValue();
    error ModuleCeilingExceeded();
    error KernelCeilingExceeded();
    error ModuleBurnExceeded();
    error NotPHOGovernance(address caller);
    error NotTONGovernance(address caller);
    error UnregisteredModule(address module);
    error ModuleRegistered();
    error DeprecatedModule(address module);

    /// events

    event Transfer(address indexed from, address indexed to, uint256 value);
    event ModuleAdded(address indexed module);
    event ModuleRemoved(address indexed module);
    event PHOCeilingUpdated(address indexed module, uint256 newPHOCeiling);
    event UpdatedModuleDelay(uint256 newDelay);
    event ModuleMint(address module, uint256 amount);
    event ModuleBurn(address module, uint256 amount);

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
        // vm.prank(owner);
        // // pho.setTeller(address(kernel));

        vm.prank(PHOGovernance);
        moduleManager.addModule(module1);

        (,, uint256 startTime, ModuleManager.Status status) = moduleManager.modules(module1);
        assertEq(uint8(status), uint8(Status.Registered));
        assertEq(startTime, block.timestamp + moduleManager.moduleDelay());
        vm.prank(TONGovernance);
        moduleManager.setPHOCeilingForModule(module1, ONE_MILLION_D18);
        (uint256 newPhoCeiling,,,) = moduleManager.modules(module1);
        assertEq(newPhoCeiling, ONE_MILLION_D18);
    }

    function testModuleManagerConstructor() public {
        IKernel kernelCheck = moduleManager.kernel();
        assertEq(address(kernelCheck), address(kernel));
        assertEq(moduleManager.PHOGovernance(), PHOGovernance);
        assertEq(moduleManager.TONGovernance(), TONGovernance);
    }

    /// mintPHO() tests

    function testCannotMintPHOUnregistered() public {
        vm.startPrank(dummyAddress);
        vm.expectRevert(abi.encodeWithSelector(UnregisteredModule.selector, dummyAddress));
        moduleManager.mintPHO(ONE_MILLION_D18);
        vm.stopPrank();
    }

    function testCannotMintPHOCeilingMax() public {
        vm.startPrank(module1);
        vm.expectRevert(abi.encodeWithSelector(ModuleCeilingExceeded.selector));
        moduleManager.mintPHO(ONE_MILLION_D18 * 2);
        vm.stopPrank();
    }

    function testMintPHO() public {
        vm.startPrank(module1);
        assertEq(pho.balanceOf(module1), 0);
        (, uint256 phoMinted,,) = moduleManager.modules(module1);
        assertEq(phoMinted, 0);
        vm.expectEmit(true, false, false, true);
        emit Transfer(address(0), module1, ONE_HUNDRED_THOUSAND_D18);
        emit ModuleMint(module1, ONE_HUNDRED_THOUSAND_D18);
        moduleManager.mintPHO(ONE_HUNDRED_THOUSAND_D18);
        (, uint256 newPhoMinted,,) = moduleManager.modules(module1);
        assertEq(pho.balanceOf(module1), ONE_HUNDRED_THOUSAND_D18);
        assertEq(newPhoMinted, ONE_HUNDRED_THOUSAND_D18);
        vm.stopPrank();
    }

    /// burnPHO() tests

    function testBurnDeprecatedModule() public {
        _moduleMintPHO();
        vm.prank(PHOGovernance);
        moduleManager.removeModule(module1);
        uint256 expectedModulePHO = pho.balanceOf(module1) - TEN_THOUSAND_D18 * 5;
        uint256 burnAmount = TEN_THOUSAND_D18 * 5;
        vm.startPrank(module1);

        pho.approve(address(kernel), pho.balanceOf(module1));
        vm.expectEmit(true, false, false, true);
        emit Transfer(module1, address(0), burnAmount);
        emit ModuleBurn(module1, burnAmount);
        moduleManager.burnPHO(burnAmount);
        assertEq(pho.balanceOf(module1), expectedModulePHO);

        (, uint256 newPhoMinted,,) = moduleManager.modules(module1);

        assertEq(newPhoMinted, expectedModulePHO);
        vm.stopPrank();
    }

    function testCannotBurnUnregistered() public {
        vm.startPrank(dummyAddress);
        vm.expectRevert(abi.encodeWithSelector(UnregisteredModule.selector, dummyAddress));
        moduleManager.burnPHO(ONE_HUNDRED_D18);
        vm.stopPrank();
    }

    function testCannotBurnZeroPHO() public {
        vm.startPrank(module1);
        vm.expectRevert(abi.encodeWithSelector(ZeroValue.selector));
        moduleManager.burnPHO(0);
        vm.stopPrank();
    }

    function testCannotBurnPastZero() public {
        vm.startPrank(module1);
        vm.expectRevert(abi.encodeWithSelector(ModuleBurnExceeded.selector));
        moduleManager.burnPHO(ONE_MILLION_D18 * 2);
        vm.stopPrank();
    }

    function testBurnPHO() public {
        _moduleMintPHO();
        uint256 expectedModulePHO = pho.balanceOf(module1) - TEN_THOUSAND_D18 * 5;
        uint256 burnAmount = TEN_THOUSAND_D18 * 5;
        vm.startPrank(module1);

        pho.approve(address(kernel), pho.balanceOf(module1));
        vm.expectEmit(true, false, false, true);
        emit Transfer(module1, address(0), burnAmount);
        emit ModuleBurn(module1, burnAmount);
        moduleManager.burnPHO(burnAmount);
        assertEq(pho.balanceOf(module1), expectedModulePHO);

        (, uint256 newPhoMinted,,) = moduleManager.modules(module1);

        assertEq(newPhoMinted, expectedModulePHO);
        vm.stopPrank();
    }

    /// addModule() tests

    function testCannotAddRegisteredModule() public {
        vm.startPrank(PHOGovernance);
        (,,, ModuleManager.Status status) = moduleManager.modules(module1);
        assertEq(uint8(status), uint8(Status.Registered));

        vm.expectRevert(abi.encodeWithSelector(ModuleRegistered.selector));
        moduleManager.addModule(module1);
        (,,, ModuleManager.Status newStatus) = moduleManager.modules(module1);
        assertEq(uint8(newStatus), uint8(Status.Registered)); // check that status hasn't changed
        vm.stopPrank();
    }

    function testCannotAddZeroAddress() public {
        vm.startPrank(PHOGovernance);
        vm.expectRevert(abi.encodeWithSelector(ZeroAddress.selector));
        moduleManager.addModule(address(0));
        vm.stopPrank();
    }

    function testCannotAddDeprecatedModule() public {
        vm.startPrank(PHOGovernance);
        moduleManager.removeModule(module1);
        (,,, ModuleManager.Status status) = moduleManager.modules(module1);
        assertEq(uint8(status), uint8(Status.Deprecated));
        vm.expectRevert(abi.encodeWithSelector(ModuleRegistered.selector));
        moduleManager.addModule(module1);
        vm.stopPrank();
    }

    function testCannotAddModuleNonPHOGovernance() public {
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(NotPHOGovernance.selector, user1));
        moduleManager.addModule(dummyAddress);
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

        vm.expectRevert(abi.encodeWithSelector(UnregisteredModule.selector, user1));
        moduleManager.removeModule(user1);
        (,,, ModuleManager.Status newStatus) = moduleManager.modules(user1);
        assertEq(uint8(newStatus), uint8(Status.Unregistered)); // check that status hasn't changed
        vm.stopPrank();
    }

    function testCannotRemoveZeroAddress() public {
        vm.startPrank(PHOGovernance);
        vm.expectRevert(abi.encodeWithSelector(ZeroAddress.selector));
        moduleManager.removeModule(address(0));
        vm.stopPrank();
    }

    function testCannotRemoveModuleNonPHOGovernance() public {
        vm.startPrank(dummyAddress);
        vm.expectRevert(abi.encodeWithSelector(NotPHOGovernance.selector, dummyAddress));
        moduleManager.removeModule(module1);
        vm.stopPrank();
    }

    function testRemoveModule() public {
        vm.startPrank(PHOGovernance);

        (,,, ModuleManager.Status status) = moduleManager.modules(module1);
        assertEq(uint8(status), uint8(Status.Registered));

        vm.expectEmit(true, false, false, true);
        emit ModuleRemoved(module1);
        moduleManager.removeModule(module1);

        (uint256 newPhoCeiling,,, ModuleManager.Status newStatus) = moduleManager.modules(module1);
        assertEq(uint8(newStatus), uint8(Status.Deprecated));

        assertEq(newPhoCeiling, 0);
        vm.stopPrank();
    }

    /// setPHOCeilingModule() tests

    function testCannotSetPHOCeilingZeroAddress() public {
        vm.startPrank(TONGovernance);
        vm.expectRevert(abi.encodeWithSelector(ZeroAddress.selector));
        moduleManager.setPHOCeilingForModule(address(0), 0);
        vm.stopPrank();
    }

    function testCannotSetPHOCeilingUnregistered() public {
        vm.startPrank(TONGovernance);
        vm.expectRevert(abi.encodeWithSelector(UnregisteredModule.selector, dummyAddress));
        moduleManager.setPHOCeilingForModule(dummyAddress, ONE_MILLION_D18);
        vm.stopPrank();
    }

    function testCannotSetPHOCeilingDeprecated() public {
        vm.prank(PHOGovernance);
        moduleManager.removeModule(module1);
        vm.startPrank(TONGovernance);
        vm.expectRevert(abi.encodeWithSelector(DeprecatedModule.selector, module1));
        moduleManager.setPHOCeilingForModule(module1, ONE_MILLION_D18);
        vm.stopPrank();
    }

    // /// TODO - this test requires kernel.PHOCeiling() to be set
    // function testCannotSetPHOCeilingMaxExceeded() public {
    //     vm.startPrank(TONGovernance);
    //     vm.expectRevert(abi.encodeWithSelector(MaxKernelPHOCeilingExceeded.selector);
    //     moduleManager.setPHOCeilingForModule(module1, kernel.PHOCeiling() + 1);
    //     vm.stopPrank();
    // }

    function testCannotSetPHOCeilingNonTONGovernance() public {
        vm.startPrank(dummyAddress);
        vm.expectRevert(abi.encodeWithSelector(NotTONGovernance.selector, dummyAddress));
        moduleManager.setPHOCeilingForModule(module1, ONE_MILLION_D18 * 10);
        vm.stopPrank();
    }

    function testSetPHOCeilingModule() public {
        uint256 expectedPHOCeiling = ONE_MILLION_D18 * 10;
        vm.startPrank(TONGovernance);
        vm.expectEmit(true, false, false, true);
        emit PHOCeilingUpdated(module1, expectedPHOCeiling);
        moduleManager.setPHOCeilingForModule(module1, ONE_MILLION_D18 * 10);

        (uint256 phoCeiling,,,) = moduleManager.modules(module1);

        assertEq(phoCeiling, expectedPHOCeiling);
        vm.stopPrank();
    }

    function testCannotSetModuleDelayToZero() public {
        vm.startPrank(PHOGovernance);
        vm.expectRevert(abi.encodeWithSelector(ZeroValue.selector));
        moduleManager.setModuleDelay(0);
        vm.stopPrank();
    }

    function testCannotSetModuleDelayOnlyPHOGovernance() public {
        vm.startPrank(dummyAddress);
        vm.expectRevert(abi.encodeWithSelector(NotPHOGovernance.selector, dummyAddress));

        moduleManager.setModuleDelay(0);
        vm.stopPrank();
    }

    function testSetModuleDelay() public {
        vm.startPrank(PHOGovernance);
        vm.expectEmit(false, false, false, true);
        emit UpdatedModuleDelay(3 weeks);
        moduleManager.setModuleDelay(3 weeks);
        assertEq(moduleManager.moduleDelay(), 3 weeks);
        vm.stopPrank();
    }

    /// helpers

    /// @notice helper function to mint 100k PHO to module1
    function _moduleMintPHO() internal {
        vm.startPrank(module1);
        assertEq(pho.balanceOf(module1), 0);
        moduleManager.mintPHO(ONE_HUNDRED_THOUSAND_D18);
        assertEq(pho.balanceOf(module1), ONE_HUNDRED_THOUSAND_D18);
        vm.stopPrank();
    }
}
