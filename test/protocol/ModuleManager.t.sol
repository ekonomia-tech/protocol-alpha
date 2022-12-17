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
    error SameValue();
    error SameAddress();
    error ModuleCeilingExceeded();
    error KernelCeilingExceeded();
    error ModuleBurnExceeded();
    error ModuleUnavailable(address module, Status status);
    error ModuleRegistered();
    error UnregisteredModule();
    error ModuleNotPaused();
    error DelayNotMet();
    error UpdateNotAvailable();
    error NotPauseGuardian();
    error NotPHOTimelock();
    error NotTONTimelock();

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

    struct Module {
        uint256 phoCeiling;
        uint256 upcomingCeiling;
        uint256 ceilingUpdateTime;
        uint256 phoMinted;
        uint256 startTime;
        Status status;
    }

    enum Status {
        Unregistered,
        Active,
        Paused,
        Deprecated
    }

    function setUp() public {
        vm.prank(address(PHOTimelock));
        moduleManager.addModule(module1);

        (,,,, uint256 startTime, ModuleManager.Status status) = moduleManager.modules(module1);
        assertEq(uint8(status), uint8(Status.Active));
        assertEq(startTime, block.timestamp + moduleManager.moduleDelay());

        vm.prank(address(TONTimelock));
        moduleManager.setPHOCeilingForModule(module1, ONE_MILLION_D18);

        vm.warp(block.timestamp + moduleManager.moduleDelay());

        moduleManager.executeCeilingUpdate(module1);

        (uint256 newPhoCeiling,,,,,) = moduleManager.modules(module1);
        assertEq(newPhoCeiling, ONE_MILLION_D18);
    }

    function testModuleManagerConstructor() public {
        IKernel kernelCheck = moduleManager.kernel();
        assertEq(address(kernelCheck), address(kernel));
        assertEq(moduleManager.PHOTimelock(), address(PHOTimelock));
        assertEq(moduleManager.TONTimelock(), address(TONTimelock));
    }

    /// mintPHO() tests

    function testCannotMintPHOUnregistered() public {
        vm.expectRevert(
            abi.encodeWithSelector(ModuleUnavailable.selector, dummyAddress, Status.Unregistered)
        );
        vm.prank(dummyAddress);
        moduleManager.mintPHO(user1, ONE_MILLION_D18);
    }

    function testCannotMintPHOCeilingMax() public {
        vm.startPrank(module1);
        vm.expectRevert(abi.encodeWithSelector(ModuleCeilingExceeded.selector));
        moduleManager.mintPHO(user1, ONE_MILLION_D18 * 2);
        vm.stopPrank();
    }

    function testMintPHO() public {
        uint256 user1BalanceBefore = pho.balanceOf(user1);
        (,,, uint256 phoMintedBefore,,) = moduleManager.modules(module1);

        vm.expectEmit(true, true, false, true);
        emit ModuleMint(module1, user1, ONE_HUNDRED_THOUSAND_D18);
        vm.prank(module1);
        moduleManager.mintPHO(user1, ONE_HUNDRED_THOUSAND_D18);

        uint256 user1BalanceAfter = pho.balanceOf(user1);
        (,,, uint256 phoMintedAfter,,) = moduleManager.modules(module1);

        assertEq(user1BalanceAfter, user1BalanceBefore + ONE_HUNDRED_THOUSAND_D18);
        assertEq(phoMintedAfter, phoMintedBefore + ONE_HUNDRED_THOUSAND_D18);
    }

    /// burnPHO() tests

    function testBurnDeprecatedModule() public {
        vm.prank(module1);
        moduleManager.mintPHO(user1, ONE_HUNDRED_THOUSAND_D18);

        vm.prank(address(PHOTimelock));
        moduleManager.deprecateModule(module1);

        uint256 burnAmount = TEN_THOUSAND_D18 * 5;
        uint256 user1BalanceBefore = pho.balanceOf(user1);
        (,,, uint256 module1PhoBalanceBefore,,) = moduleManager.modules(module1);

        vm.prank(user1);
        pho.approve(address(kernel), burnAmount);

        vm.expectEmit(true, true, false, true);
        emit ModuleBurn(module1, user1, burnAmount);
        vm.prank(module1);
        moduleManager.burnPHO(user1, burnAmount);

        uint256 user1BalanceAfter = pho.balanceOf(user1);
        (,,, uint256 module1PhoBalanceAfter,,) = moduleManager.modules(module1);

        assertEq(user1BalanceBefore, user1BalanceAfter + burnAmount);
        assertEq(module1PhoBalanceBefore, module1PhoBalanceAfter + burnAmount);
    }

    function testCannotBurnUnregistered() public {
        vm.expectRevert(abi.encodeWithSelector(UnregisteredModule.selector));
        vm.prank(dummyAddress);
        moduleManager.burnPHO(user1, ONE_HUNDRED_D18);
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
        (,,, uint256 module1phoMintedBefore,,) = moduleManager.modules(module1);
        uint256 user1BalanceBefore = pho.balanceOf(user1);

        vm.prank(user1);
        pho.approve(address(kernel), burnAmount);

        vm.expectEmit(true, true, false, true);
        emit ModuleBurn(module1, user1, burnAmount);
        vm.prank(module1);
        moduleManager.burnPHO(user1, burnAmount);

        (,,, uint256 module1phoMintedAfter,,) = moduleManager.modules(module1);
        uint256 user1BalanceAfter = pho.balanceOf(user1);

        assertEq(module1phoMintedBefore, module1phoMintedAfter + burnAmount);
        assertEq(user1BalanceBefore, user1BalanceAfter + burnAmount);
    }

    /// addModule() tests

    function testCannotAddModuleAlreadyRegistered() public {
        vm.expectRevert(abi.encodeWithSelector(ModuleRegistered.selector));
        vm.prank(address(PHOTimelock));
        moduleManager.addModule(module1);
    }

    function testCannotAddZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroAddress.selector));
        vm.prank(address(PHOTimelock));
        moduleManager.addModule(address(0));
    }

    function testCannotAddDeprecatedModule() public {
        vm.startPrank(address(PHOTimelock));
        moduleManager.deprecateModule(module1);

        vm.expectRevert(abi.encodeWithSelector(ModuleRegistered.selector));
        moduleManager.addModule(module1);
        vm.stopPrank();
    }

    function testCannotAddModuleNonPHOGovernance() public {
        vm.expectRevert(abi.encodeWithSelector(NotPHOTimelock.selector));
        vm.prank(user1);
        moduleManager.addModule(dummyAddress);
    }

    function testAddModule() public {
        address module2 = address(8);

        vm.expectEmit(true, false, false, true);
        emit ModuleAdded(module2);
        vm.prank(address(PHOTimelock));
        moduleManager.addModule(module2);

        (,,,, uint256 newStartTime, ModuleManager.Status newStatus) = moduleManager.modules(module2);
        assertEq(uint8(newStatus), uint8(Status.Active));
        assertEq(newStartTime, block.timestamp + moduleManager.moduleDelay());
    }

    /// deprecateModule() tests

    function testCannotDeprecateUnRegisteredModule() public {
        address unregisteredModule = address(10);

        vm.expectRevert(abi.encodeWithSelector(UnregisteredModule.selector));
        vm.prank(address(PHOTimelock));
        moduleManager.deprecateModule(unregisteredModule);
    }

    function testCannotRemoveZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroAddress.selector));
        vm.prank(address(PHOTimelock));
        moduleManager.deprecateModule(address(0));
    }

    function testCannotRemoveModuleNonPHOGovernance() public {
        vm.expectRevert(abi.encodeWithSelector(NotPHOTimelock.selector));
        vm.prank(dummyAddress);
        moduleManager.deprecateModule(module1);
    }

    function testRemoveModule() public {
        vm.expectEmit(true, false, false, true);
        emit ModuleDeprecated(module1);
        vm.prank(address(PHOTimelock));
        moduleManager.deprecateModule(module1);

        (uint256 newPhoCeiling,,,,, ModuleManager.Status newStatus) = moduleManager.modules(module1);
        assertEq(uint8(newStatus), uint8(Status.Deprecated));
        assertEq(newPhoCeiling, 0);
    }

    /// setPHOCeilingModule() tests

    function testCannotSetPHOCeilingZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroAddress.selector));
        vm.prank(address(TONTimelock));
        moduleManager.setPHOCeilingForModule(address(0), 0);
    }

    function testCannotSetPHOCeilingUnregistered() public {
        vm.expectRevert(
            abi.encodeWithSelector(ModuleUnavailable.selector, dummyAddress, Status.Unregistered)
        );
        vm.prank(address(TONTimelock));
        moduleManager.setPHOCeilingForModule(dummyAddress, ONE_MILLION_D18);
    }

    function testCannotSetPHOCeilingDeprecated() public {
        vm.prank(address(PHOTimelock));
        moduleManager.deprecateModule(module1);

        vm.expectRevert(
            abi.encodeWithSelector(ModuleUnavailable.selector, module1, Status.Deprecated)
        );
        vm.prank(address(TONTimelock));
        moduleManager.setPHOCeilingForModule(module1, ONE_MILLION_D18);
    }

    function testCannotSetPHOCeilingSameValue() public {
        (uint256 currentCeiling,,,,,) = moduleManager.modules(module1);
        vm.expectRevert(abi.encodeWithSelector(SameValue.selector));
        vm.prank(address(TONTimelock));
        moduleManager.setPHOCeilingForModule(module1, currentCeiling);
    }

    function testCannotSetPHOCeilingNonTONGovernance() public {
        vm.expectRevert(abi.encodeWithSelector(NotTONTimelock.selector));
        vm.prank(dummyAddress);
        moduleManager.setPHOCeilingForModule(module1, ONE_MILLION_D18 * 10);
    }

    function testSetPHOCeilingModule() public {
        uint256 newPhoCeiling = ONE_MILLION_D18 * 10;
        uint256 newCeilingUpdateTime = block.timestamp + moduleManager.moduleDelay();

        vm.expectEmit(true, false, false, true);
        emit PHOCeilingUpdateScheduled(module1, newPhoCeiling, newCeilingUpdateTime);
        vm.prank(address(TONTimelock));
        moduleManager.setPHOCeilingForModule(module1, newPhoCeiling);

        (, uint256 upcomingCeiling, uint256 ceilingUpdateTime,,,) = moduleManager.modules(module1);
        assertEq(upcomingCeiling, newPhoCeiling);
        assertEq(ceilingUpdateTime, newCeilingUpdateTime);
    }

    /// executeCeilingUpdate()

    function testCannotExecuteCeilingUpdateZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroAddress.selector));
        moduleManager.executeCeilingUpdate(address(0));
    }

    function testCannotExecuteCeilingUpdateModuleNotAvailable() public {
        vm.expectRevert(
            abi.encodeWithSelector(ModuleUnavailable.selector, address(200), Status.Unregistered)
        );
        moduleManager.executeCeilingUpdate(address(200));

        vm.prank(guardianAddress);
        moduleManager.pauseModule(module1);

        vm.expectRevert(abi.encodeWithSelector(ModuleUnavailable.selector, module1, Status.Paused));
        moduleManager.executeCeilingUpdate(module1);

        vm.prank(guardianAddress);
        moduleManager.unpauseModule(module1);

        vm.prank(address(PHOTimelock));
        moduleManager.deprecateModule(module1);

        vm.expectRevert(
            abi.encodeWithSelector(ModuleUnavailable.selector, module1, Status.Deprecated)
        );
        moduleManager.executeCeilingUpdate(module1);
    }

    function testCannotExecuteCeilingUpdateModuleUpdateNotAvailable() public {
        vm.expectRevert(abi.encodeWithSelector(UpdateNotAvailable.selector));
        moduleManager.executeCeilingUpdate(module1);
    }

    function testCannotExecuteCeilingUpdateModuleDelayNotMet() public {
        (uint256 ceilingBefore,,,,,) = moduleManager.modules(module1);
        vm.prank(address(TONTimelock));
        moduleManager.setPHOCeilingForModule(module1, 2 * ceilingBefore);

        vm.expectRevert(abi.encodeWithSelector(DelayNotMet.selector));
        moduleManager.executeCeilingUpdate(module1);
    }

    function testExecuteCeilingUpdate() public {
        (uint256 ceilingBefore,,,,,) = moduleManager.modules(module1);
        uint256 newCeiling = ceilingBefore * 2;

        vm.prank(address(TONTimelock));
        moduleManager.setPHOCeilingForModule(module1, newCeiling);

        vm.warp(block.timestamp + moduleManager.moduleDelay());

        vm.expectEmit(true, false, false, true);
        emit PHOCeilingUpdated(module1, newCeiling);
        moduleManager.executeCeilingUpdate(module1);

        (uint256 ceilingAfter, uint256 upcomingCeiling, uint256 ceilingUpdateTime,,,) =
            moduleManager.modules(module1);

        assertEq(ceilingAfter, newCeiling);
        assertEq(upcomingCeiling, 0);
        assertEq(ceilingUpdateTime, 0);
    }

    /// setModuleDelay()

    function testCannotSetModuleDelayToZero() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroValue.selector));
        vm.prank(address(PHOTimelock));
        moduleManager.setModuleDelay(0);
    }

    function testCannotSetModuleDelayOnlyPHOTimelock() public {
        vm.expectRevert(abi.encodeWithSelector(NotPHOTimelock.selector));
        vm.prank(dummyAddress);
        moduleManager.setModuleDelay(0);
    }

    function testSetModuleDelay() public {
        vm.expectEmit(false, false, false, true);
        emit UpdatedModuleDelay(3 weeks);
        vm.prank(address(PHOTimelock));
        moduleManager.setModuleDelay(3 weeks);
        assertEq(moduleManager.moduleDelay(), 3 weeks);
    }

    /// pauseModule()

    function testPauseModule() public {
        vm.expectEmit(true, false, false, true);
        emit ModulePaused(module1);
        vm.prank(guardianAddress);
        moduleManager.pauseModule(module1);
    }

    function testCannotPauseModuleZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroAddress.selector));
        vm.prank(guardianAddress);
        moduleManager.pauseModule(address(0));
    }

    function testCannotPauseModuleNotActive() public {
        vm.prank(address(PHOTimelock));
        moduleManager.deprecateModule(module1);

        vm.prank(guardianAddress);
        vm.expectRevert(
            abi.encodeWithSelector(ModuleUnavailable.selector, module1, Status.Deprecated)
        );
        moduleManager.pauseModule(module1);

        vm.prank(guardianAddress);
        vm.expectRevert(
            abi.encodeWithSelector(ModuleUnavailable.selector, address(10001), Status.Unregistered)
        );
        moduleManager.pauseModule(address(10001));
    }

    function testCannotPauseModuleAlreadyPaused() public {
        vm.prank(guardianAddress);
        moduleManager.pauseModule(module1);
        vm.expectRevert(abi.encodeWithSelector(ModuleUnavailable.selector, module1, Status.Paused));
        vm.prank(guardianAddress);
        moduleManager.pauseModule(module1);
    }

    function testCannotPauseModuleNotPauseGuardian() public {
        vm.prank(address(PHOTimelock));
        vm.expectRevert(abi.encodeWithSelector(NotPauseGuardian.selector));
        moduleManager.pauseModule(module1);
    }

    /// unpauseModule()

    function testUnpauseModule() public {
        vm.prank(guardianAddress);
        moduleManager.pauseModule(module1);
        vm.expectEmit(true, false, false, true);
        emit ModuleUnpaused(module1);
        vm.prank(guardianAddress);
        moduleManager.unpauseModule(module1);
    }

    function testCannotUnpauseModuleZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroAddress.selector));
        vm.prank(guardianAddress);
        moduleManager.unpauseModule(address(0));
    }

    function testCannotUnpauseModuleNotPaused() public {
        vm.startPrank(guardianAddress);

        vm.expectRevert(abi.encodeWithSelector(ModuleNotPaused.selector));
        moduleManager.unpauseModule(module1);

        vm.expectRevert(abi.encodeWithSelector(ModuleNotPaused.selector));
        moduleManager.unpauseModule(dummyAddress);

        vm.stopPrank();

        vm.prank(address(PHOTimelock));
        moduleManager.deprecateModule(module1);

        vm.prank(guardianAddress);
        vm.expectRevert(abi.encodeWithSelector(ModuleNotPaused.selector));
        moduleManager.unpauseModule(module1);
    }

    function testCannotUnpauseModuleNotPauseGuardian() public {
        vm.prank(guardianAddress);
        moduleManager.pauseModule(module1);

        vm.prank(address(PHOTimelock));
        vm.expectRevert(abi.encodeWithSelector(NotPauseGuardian.selector));
        moduleManager.unpauseModule(module1);
    }

    /// setPauseGuardian()

    function testSetPauseGuardian() public {
        address newPauseGuardian = address(667);
        vm.expectEmit(false, false, false, true);
        emit PauseGuardianUpdated(newPauseGuardian);
        vm.prank(address(TONTimelock));
        moduleManager.setPauseGuardian(newPauseGuardian);
    }

    function testCannotSetPauseGuardianNotTONTimelock() public {
        vm.expectRevert(abi.encodeWithSelector(NotTONTimelock.selector));
        vm.prank(user1);
        moduleManager.setPauseGuardian(address(667));
    }

    function testCannotSetPauseGuardianSameAddress() public {
        address newPauseGuardian = guardianAddress;
        vm.expectRevert(abi.encodeWithSelector(SameAddress.selector));
        vm.prank(address(TONTimelock));
        moduleManager.setPauseGuardian(newPauseGuardian);
    }
}
