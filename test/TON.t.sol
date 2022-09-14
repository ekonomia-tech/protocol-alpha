// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/contracts/TON.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./BaseSetup.t.sol";

contract TONTest is BaseSetup {
    event TellerSet(address indexed tellerAddress);
    event TONBurned(address indexed from, uint256 amount);
    event TONMinted(address indexed from, address indexed to, uint256 amount);
    event TimelockSet(address indexed newTimelockAddress);
    event ControllerSet(address indexed controllerAddress);

    function setUp() public {
        vm.prank(owner);
        ton.transfer(user1, tenThousand_d18);
    }

    function testConstructor() public {
        assertEq(ton.totalSupply(), GENESIS_SUPPLY_d18);
        assertEq(ton.balanceOf(owner), GENESIS_SUPPLY_d18 - tenThousand_d18);
        assertEq(ton.timelockAddress(), timelock_address);
    }

    /// burn()

    function testBurn() public {
        uint256 userBalanceBefore = ton.balanceOf(user1);
        uint256 totalSupplyBefore = ton.totalSupply();

        vm.prank(user1);
        ton.approve(owner, fiveHundred_d18);

        vm.expectEmit(true, true, false, true);
        emit TONBurned(user1, fiveHundred_d18);
        vm.prank(owner);
        ton.burn(user1, fiveHundred_d18);

        uint256 userBalanceAfter = ton.balanceOf(user1);
        uint256 totalSupplyAfter = ton.totalSupply();

        assertEq(userBalanceBefore, userBalanceAfter + fiveHundred_d18);
        assertEq(totalSupplyBefore, totalSupplyAfter + fiveHundred_d18);
    }

    function testCannotBurnNotAllowed() public {
        vm.expectRevert("TON: Not the owner, controller, or the governance timelock");
        vm.prank(user1);
        ton.burn(owner, fiveHundred_d18);
    }

    /// setController()

    function testSetController() public {
        vm.startPrank(owner);
        address initialController = ton.controllerAddress();
        vm.expectEmit(false, false, false, true);
        emit ControllerSet(user1);
        ton.setController(user1);

        assertTrue(initialController != ton.controllerAddress());
        assertEq(ton.controllerAddress(), user1);
        vm.stopPrank();
    }

    function testCannotSetControllerAddressZero() public {
        vm.expectRevert("TON: zero address detected");
        vm.prank(owner);
        ton.setController(address(0));
    }

    function testCannotSetControllerNotAllowed() public {
        vm.expectRevert("TON: Not the owner, controller, or the governance timelock");
        vm.prank(user1);
        ton.setController(address(0));
    }

    function testCannotSetControllerSameAddress() public {
        address currentController = ton.controllerAddress();
        vm.expectRevert("TON: same address detected");
        vm.prank(owner);
        ton.setController(currentController);
    }

    /// setTimelock()

    function testSetTimelock() public {
        vm.startPrank(owner);
        address initialTimelock = ton.controllerAddress();
        vm.expectEmit(false, false, false, true);
        emit TimelockSet(user1);
        ton.setTimelock(user1);

        assertTrue(initialTimelock != ton.timelockAddress());
        assertEq(ton.timelockAddress(), user1);
        vm.stopPrank();
    }

    function testCannotSetTimelockAddressZero() public {
        vm.expectRevert("TON: zero address detected");
        vm.prank(owner);
        ton.setTimelock(address(0));
    }

    function testCannotSetTimelockNotAllowed() public {
        vm.expectRevert("TON: Not the owner, controller, or the governance timelock");
        vm.prank(user1);
        ton.setTimelock(address(0));
    }

    function testCannotSetTimelockSameAddress() public {
        address currentTimelock = ton.timelockAddress();
        vm.expectRevert("TON: same address detected");
        vm.prank(owner);
        ton.setTimelock(currentTimelock);
    }
}
