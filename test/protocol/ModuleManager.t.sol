// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import "../BaseSetup.t.sol";
import "@protocol/contracts/PHO.sol";
import "@protocol/interfaces/IKernel.sol";
import "@protocol/contracts/ModuleManager.sol";

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
    event ModuleDeprecated(address indexed module);
    event PHOCeilingUpdated(address indexed module, uint256 newPHOCeiling);
    event UpdatedModuleDelay(uint256 newDelay);
    event ModuleMint(address indexed module, address indexed to, uint256 amount);
    event ModuleBurn(address indexed module, address indexed from, uint256 amount);

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
        moduleManager.mintPHO(user1, ONE_MILLION_D18);
        vm.stopPrank();
    }

    function testCannotMintPHOCeilingMax() public {
        vm.startPrank(module1);
        vm.expectRevert(abi.encodeWithSelector(ModuleCeilingExceeded.selector));
        moduleManager.mintPHO(user1, ONE_MILLION_D18 * 2);
        vm.stopPrank();
    }

    function testMintPHO() public {
        uint256 user1BalanceBefore = pho.balanceOf(user1);
        (, uint256 phoMintedBefore,,) = moduleManager.modules(module1);

        vm.expectEmit(true, true, false, true);
        emit ModuleMint(module1, user1, ONE_HUNDRED_THOUSAND_D18);
        vm.prank(module1);
        moduleManager.mintPHO(user1, ONE_HUNDRED_THOUSAND_D18);

        uint256 user1BalanceAfter = pho.balanceOf(user1);
        (, uint256 phoMintedAfter,,) = moduleManager.modules(module1);

        assertEq(user1BalanceAfter, user1BalanceBefore + ONE_HUNDRED_THOUSAND_D18);
        assertEq(phoMintedAfter, phoMintedBefore + ONE_HUNDRED_THOUSAND_D18);
    }

    /// burnPHO() tests

    function testBurnDeprecatedModule() public {
        vm.prank(module1);
        moduleManager.mintPHO(user1, ONE_HUNDRED_THOUSAND_D18);

        vm.prank(PHOGovernance);
        moduleManager.deprecateModule(module1);

        uint256 burnAmount = TEN_THOUSAND_D18 * 5;
        uint256 user1BalanceBefore = pho.balanceOf(user1);
        (, uint256 module1PhoBalanceBefore,,) = moduleManager.modules(module1);

        vm.prank(user1);
        pho.approve(address(kernel), burnAmount);

        vm.expectEmit(true, true, false, true);
        emit ModuleBurn(module1, user1, burnAmount);
        vm.prank(module1);
        moduleManager.burnPHO(user1, burnAmount);

        uint256 user1BalanceAfter = pho.balanceOf(user1);
        (, uint256 module1PhoBalanceAfter,,) = moduleManager.modules(module1);

        assertEq(user1BalanceBefore, user1BalanceAfter + burnAmount);
        assertEq(module1PhoBalanceBefore, module1PhoBalanceAfter + burnAmount);
    }

    function testCannotBurnUnregistered() public {
        vm.startPrank(dummyAddress);
        vm.expectRevert(abi.encodeWithSelector(UnregisteredModule.selector, dummyAddress));
        moduleManager.burnPHO(user1, ONE_HUNDRED_D18);
        vm.stopPrank();
    }

    function testCannotBurnZeroPHO() public {
        vm.startPrank(module1);
        vm.expectRevert(abi.encodeWithSelector(ZeroValue.selector));
        moduleManager.burnPHO(user1, 0);
        vm.stopPrank();
    }

    function testCannotBurnPastZero() public {
        vm.startPrank(module1);
        vm.expectRevert(abi.encodeWithSelector(ModuleBurnExceeded.selector));
        moduleManager.burnPHO(user1, ONE_MILLION_D18 * 2);
        vm.stopPrank();
    }

    function testBurnPHO() public {
        vm.prank(module1);
        moduleManager.mintPHO(user1, ONE_HUNDRED_THOUSAND_D18);

        uint256 burnAmount = TEN_THOUSAND_D18 * 5;
        (, uint256 module1phoMintedBefore,,) = moduleManager.modules(module1);
        uint256 user1BalanceBefore = pho.balanceOf(user1);

        vm.prank(user1);
        pho.approve(address(kernel), burnAmount);

        vm.expectEmit(true, true, false, true);
        emit ModuleBurn(module1, user1, burnAmount);
        vm.prank(module1);
        moduleManager.burnPHO(user1, burnAmount);

        (, uint256 module1phoMintedAfter,,) = moduleManager.modules(module1);
        uint256 user1BalanceAfter = pho.balanceOf(user1);

        assertEq(module1phoMintedBefore, module1phoMintedAfter + burnAmount);
        assertEq(user1BalanceBefore, user1BalanceAfter + burnAmount);
    }

    /// addModule() tests

    function testCannotAddModuleAlreadyRegistered() public {
        vm.expectRevert(abi.encodeWithSelector(ModuleRegistered.selector));
        vm.prank(PHOGovernance);
        moduleManager.addModule(module1);
    }

    function testCannotAddZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroAddress.selector));
        vm.prank(PHOGovernance);
        moduleManager.addModule(address(0));
    }

    function testCannotAddDeprecatedModule() public {
        vm.startPrank(PHOGovernance);
        moduleManager.deprecateModule(module1);

        vm.expectRevert(abi.encodeWithSelector(ModuleRegistered.selector));
        moduleManager.addModule(module1);
        vm.stopPrank();
    }

    function testCannotAddModuleNonPHOGovernance() public {
        vm.expectRevert(abi.encodeWithSelector(NotPHOGovernance.selector, user1));
        vm.prank(user1);
        moduleManager.addModule(dummyAddress);
    }

    function testAddModule() public {
        address module2 = address(8);

        vm.expectEmit(true, false, false, true);
        emit ModuleAdded(module2);
        vm.prank(PHOGovernance);
        moduleManager.addModule(module2);

        (,, uint256 newStartTime, ModuleManager.Status newStatus) = moduleManager.modules(module2);
        assertEq(uint8(newStatus), uint8(Status.Registered));
        assertEq(newStartTime, block.timestamp + moduleManager.moduleDelay());
    }

    /// deprecateModule() tests

    function testCannotDeprecateUnRegisteredModule() public {
        address unregisteredModule = address(10);

        vm.expectRevert(abi.encodeWithSelector(UnregisteredModule.selector, unregisteredModule));
        vm.prank(PHOGovernance);
        moduleManager.deprecateModule(unregisteredModule);
    }

    function testCannotRemoveZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroAddress.selector));
        vm.prank(PHOGovernance);
        moduleManager.deprecateModule(address(0));
    }

    function testCannotRemoveModuleNonPHOGovernance() public {
        vm.expectRevert(abi.encodeWithSelector(NotPHOGovernance.selector, dummyAddress));
        vm.prank(dummyAddress);
        moduleManager.deprecateModule(module1);
    }

    function testRemoveModule() public {
        vm.expectEmit(true, false, false, true);
        emit ModuleDeprecated(module1);
        vm.prank(PHOGovernance);
        moduleManager.deprecateModule(module1);

        (uint256 newPhoCeiling,,, ModuleManager.Status newStatus) = moduleManager.modules(module1);
        assertEq(uint8(newStatus), uint8(Status.Deprecated));
        assertEq(newPhoCeiling, 0);
    }

    /// setPHOCeilingModule() tests

    function testCannotSetPHOCeilingZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroAddress.selector));
        vm.prank(TONGovernance);
        moduleManager.setPHOCeilingForModule(address(0), 0);
    }

    function testCannotSetPHOCeilingUnregistered() public {
        vm.expectRevert(abi.encodeWithSelector(UnregisteredModule.selector, dummyAddress));
        vm.prank(TONGovernance);
        moduleManager.setPHOCeilingForModule(dummyAddress, ONE_MILLION_D18);
    }

    function testCannotSetPHOCeilingDeprecated() public {
        vm.prank(PHOGovernance);
        moduleManager.deprecateModule(module1);

        vm.expectRevert(abi.encodeWithSelector(DeprecatedModule.selector, module1));
        vm.prank(TONGovernance);
        moduleManager.setPHOCeilingForModule(module1, ONE_MILLION_D18);
    }

    function testCannotSetPHOCeilingNonTONGovernance() public {
        vm.expectRevert(abi.encodeWithSelector(NotTONGovernance.selector, dummyAddress));
        vm.prank(dummyAddress);
        moduleManager.setPHOCeilingForModule(module1, ONE_MILLION_D18 * 10);
    }

    function testSetPHOCeilingModule() public {
        uint256 newPhoCeiling = ONE_MILLION_D18 * 10;

        vm.expectEmit(true, false, false, true);
        emit PHOCeilingUpdated(module1, newPhoCeiling);
        vm.prank(TONGovernance);
        moduleManager.setPHOCeilingForModule(module1, newPhoCeiling);

        (uint256 phoCeiling,,,) = moduleManager.modules(module1);
        assertEq(phoCeiling, newPhoCeiling);
    }

    function testCannotSetModuleDelayToZero() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroValue.selector));
        vm.prank(PHOGovernance);
        moduleManager.setModuleDelay(0);
    }

    function testCannotSetModuleDelayOnlyPHOGovernance() public {
        vm.expectRevert(abi.encodeWithSelector(NotPHOGovernance.selector, dummyAddress));
        vm.prank(dummyAddress);
        moduleManager.setModuleDelay(0);
    }

    function testSetModuleDelay() public {
        vm.expectEmit(false, false, false, true);
        emit UpdatedModuleDelay(3 weeks);
        vm.prank(PHOGovernance);
        moduleManager.setModuleDelay(3 weeks);
        assertEq(moduleManager.moduleDelay(), 3 weeks);
    }
}
