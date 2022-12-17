// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "@protocol/contracts/TON.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../BaseSetup.t.sol";

contract KernelTest is BaseSetup {
    error ZeroAddress();
    error ZeroValue();
    error SameAddress();
    error SameValue();
    error NotModuleManager(address caller);
    error NotTONTimelock();

    event ModuleManagerDelayUpdated(uint256 newDelay);
    event ModuleManagerUpdated(address indexed newModuleManager);

    /// mintPHO()

    function testMintPHO() public {
        uint256 user1PHOBalanceBefore = pho.balanceOf(user1);
        uint256 phoTotalSupplyBefore = pho.totalSupply();

        vm.prank(address(moduleManager));
        kernel.mintPHO(user1, TEN_THOUSAND_D18);

        uint256 user1PHOBalanceAfter = pho.balanceOf(user1);
        uint256 phoTotalSupplyAfter = pho.totalSupply();

        assertEq(user1PHOBalanceAfter, user1PHOBalanceBefore + TEN_THOUSAND_D18);
        assertEq(phoTotalSupplyAfter, phoTotalSupplyBefore + TEN_THOUSAND_D18);
    }

    function testCannotMintPHONotApproved() public {
        vm.expectRevert(abi.encodeWithSelector(NotModuleManager.selector, user1));
        vm.prank(user1);
        kernel.mintPHO(owner, TEN_THOUSAND_D18);
    }

    function testCannotMintPhoZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroAddress.selector));
        vm.prank(address(moduleManager));
        kernel.mintPHO(address(0), TEN_THOUSAND_D18);
    }

    function testCannotMintPhoZeroValue() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroValue.selector));
        vm.prank(address(moduleManager));
        kernel.mintPHO(user1, 0);
    }

    /// burnPHO()

    function testBurnPHO() public {
        testMintPHO();

        uint256 user1BalanceBefore = pho.balanceOf(user1);
        uint256 phoTotalSupplyBefore = pho.totalSupply();

        vm.prank(user1);
        pho.approve(address(kernel), TEN_THOUSAND_D18);

        vm.prank(address(moduleManager));
        kernel.burnPHO(user1, TEN_THOUSAND_D18);

        uint256 user1BalanceAfter = pho.balanceOf(user1);
        uint256 phoTotalSupplyAfter = pho.totalSupply();

        assertEq(user1BalanceAfter, user1BalanceBefore - TEN_THOUSAND_D18);
        assertEq(phoTotalSupplyAfter, phoTotalSupplyBefore - TEN_THOUSAND_D18);
    }

    function testCannotBurnPHONotApproved() public {
        vm.expectRevert(abi.encodeWithSelector(NotModuleManager.selector, user1));
        vm.prank(user1);
        kernel.burnPHO(owner, TEN_THOUSAND_D18);
    }

    function testCannotBurnPhoZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroAddress.selector));
        vm.prank(address(moduleManager));
        kernel.burnPHO(address(0), TEN_THOUSAND_D18);
    }

    function testCannotBurnPhoZeroValue() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroValue.selector));
        vm.prank(address(moduleManager));
        kernel.burnPHO(user1, 0);
    }

    /// updateModuleManagerDelay()

    function testUpdateModuleManagerDelay() public {
        uint256 newDelay = 2 weeks;
        vm.expectEmit(true, false, false, true);
        emit ModuleManagerDelayUpdated(newDelay);
        vm.prank(address(TONTimelock));
        kernel.updateModuleManagerDelay(newDelay);
    }

    function testCannotUpdateModuleManagerDelayUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(NotTONTimelock.selector));
        vm.prank(user1);
        kernel.updateModuleManagerDelay(2 weeks);
    }

    function testCannotUpdateModuleManagerDelayZeroValue() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroValue.selector));
        vm.prank(address(TONTimelock));
        kernel.updateModuleManagerDelay(0);
    }

    function testCannotUpdateModuleManagerDelaySameValue() public {
        vm.expectRevert(abi.encodeWithSelector(SameValue.selector));
        vm.prank(address(TONTimelock));
        kernel.updateModuleManagerDelay(4 weeks);
    }

    /// updateModuleManager()

    function testUpdateModuleManager() public {
        address newModuleManager = address(205);
        vm.expectEmit(true, false, false, true);
        emit ModuleManagerUpdated(newModuleManager);
        vm.prank(address(TONTimelock));
        kernel.updateModuleManager(newModuleManager);
    }

    function testCannotAddModuleManagerUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(NotTONTimelock.selector));
        vm.prank(user1);
        kernel.updateModuleManager(address(205));
    }

    function testCannotAddModuleManagerZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroAddress.selector));
        vm.prank(address(TONTimelock));
        kernel.updateModuleManager(address(0));
    }

    function testCannotAddModuleManagerSameAddress() public {
        vm.expectRevert(abi.encodeWithSelector(SameAddress.selector));
        vm.prank(address(TONTimelock));
        kernel.updateModuleManager(address(moduleManager));
    }
}
