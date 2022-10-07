// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/contracts/TON.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./BaseSetup.t.sol";

contract KernelTest is BaseSetup {
    error ZeroAddressDetected();
    error ZeroValueDetected();
    error SameAddressDetected();
    error SameValueDetected();
    error Unauthorized_NotModuleManager(address caller);
    error Unauthorized_NotTONGovernance(address caller);

    event ModuleManagerDelayUpdated(uint256 newDelay);
    event DispatcherDelayUpdated(uint256 newDelay);
    event ModuleDelayUpdated(uint256 newDelay);
    event DispatcherUpdated(address indexed newDispatcher);
    event ModuleManagerUpdated(address indexed newModuleManager);

    /// mintPHO()

    function testMintPHO() public {
        uint256 ownerPHOBalanceBefore = pho.balanceOf(owner);
        uint256 phoTotalSupplyBefore = pho.totalSupply();

        vm.prank(moduleManager);
        kernel.mintPHO(owner, TEN_THOUSAND_D18);

        uint256 ownerPHOBalanceAfter = pho.balanceOf(owner);
        uint256 phoTotalSupplyAfter = pho.totalSupply();

        assertEq(ownerPHOBalanceAfter, ownerPHOBalanceBefore + TEN_THOUSAND_D18);
        assertEq(phoTotalSupplyAfter, phoTotalSupplyBefore + TEN_THOUSAND_D18);
    }

    function testCannotMintPHONotApproved() public {
        vm.expectRevert(abi.encodeWithSelector(Unauthorized_NotModuleManager.selector, user1));
        vm.prank(user1);
        kernel.mintPHO(owner, TEN_THOUSAND_D18);
    }

    function testCannotMintPhoZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        vm.prank(moduleManager);
        kernel.mintPHO(address(0), TEN_THOUSAND_D18);
    }

    function testCannotMintPhoZeroValue() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroValueDetected.selector));
        vm.prank(moduleManager);
        kernel.mintPHO(user1, 0);
    }

    /// burnPHO()

    function testBurnPHO() public {
        testMintPHO();

        uint256 ownerBalanceBefore = pho.balanceOf(owner);
        uint256 phoTotalSupplyBefore = pho.totalSupply();

        vm.prank(owner);
        pho.approve(address(kernel), TEN_THOUSAND_D18);

        vm.prank(moduleManager);
        kernel.burnPHO(owner, TEN_THOUSAND_D18);

        uint256 ownerBalanceAfter = pho.balanceOf(owner);
        uint256 phoTotalSupplyAfter = pho.totalSupply();

        assertEq(ownerBalanceAfter, ownerBalanceBefore - TEN_THOUSAND_D18);
        assertEq(phoTotalSupplyAfter, phoTotalSupplyBefore - TEN_THOUSAND_D18);
    }

    function testCannotBurnPHONotApproved() public {
        vm.expectRevert(abi.encodeWithSelector(Unauthorized_NotModuleManager.selector, user1));
        vm.prank(user1);
        kernel.burnPHO(owner, TEN_THOUSAND_D18);
    }

    function testCannotBurnPhoZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        vm.prank(moduleManager);
        kernel.burnPHO(address(0), TEN_THOUSAND_D18);
    }

    function testCannotBurnPhoZeroValue() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroValueDetected.selector));
        vm.prank(moduleManager);
        kernel.burnPHO(user1, 0);
    }

    /// updateModuleManagerDelay()

    function testUpdateModuleManagerDelay() public {
        uint256 newDelay = 2 weeks;
        vm.expectEmit(true, false, false, true);
        emit ModuleManagerDelayUpdated(newDelay);
        vm.prank(TONGovernance);
        kernel.updateModuleManagerDelay(newDelay);
    }

    function testCannotUpdateModuleManagerDelayUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Unauthorized_NotTONGovernance.selector, user1));
        vm.prank(user1);
        kernel.updateModuleManagerDelay(2 weeks);
    }

    function testCannotUpdateModuleManagerDelayZeroValue() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroValueDetected.selector));
        vm.prank(TONGovernance);
        kernel.updateModuleManagerDelay(0);
    }

    function testCannotUpdateModuleManagerDelaySameValue() public {
        vm.expectRevert(abi.encodeWithSelector(SameValueDetected.selector));
        vm.prank(TONGovernance);
        kernel.updateModuleManagerDelay(4 weeks);
    }

    /// updateDispatcherDelay()

    function testUpdateDispatcherDelay() public {
        uint256 newDelay = 2 weeks;
        vm.expectEmit(true, false, false, true);
        emit DispatcherDelayUpdated(newDelay);
        vm.prank(TONGovernance);
        kernel.updateDispatcherDelay(newDelay);
    }

    function testCannotUpdateDispatcherDelayUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Unauthorized_NotTONGovernance.selector, user1));
        vm.prank(user1);
        kernel.updateDispatcherDelay(2 weeks);
    }

    function testCannotUpdateDispatcherDelayZeroValue() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroValueDetected.selector));
        vm.prank(TONGovernance);
        kernel.updateDispatcherDelay(0);
    }

    function testCannotUpdateDispatcherDelaySameValue() public {
        vm.expectRevert(abi.encodeWithSelector(SameValueDetected.selector));
        vm.prank(TONGovernance);
        kernel.updateDispatcherDelay(4 weeks);
    }

    /// updateDispatcher()

    function testUpdateDispatcher() public {
        address newDispatcher = address(205);
        vm.expectEmit(true, false, false, true);
        emit DispatcherUpdated(newDispatcher);
        vm.prank(TONGovernance);
        kernel.updateDispatcher(newDispatcher);
    }

    function testCannotAddDispatcherUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Unauthorized_NotTONGovernance.selector, user1));
        vm.prank(user1);
        kernel.updateDispatcher(address(205));
    }

    function testCannotAddDispatcherZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        vm.prank(TONGovernance);
        kernel.updateDispatcher(address(0));
    }

    function testCannotAddDispatcherSameAddress() public {
        vm.expectRevert(abi.encodeWithSelector(SameAddressDetected.selector));
        vm.prank(TONGovernance);
        kernel.updateDispatcher(address(dispatcher));
    }
}
