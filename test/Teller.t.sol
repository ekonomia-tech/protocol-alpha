// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/contracts/TON.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./BaseSetup.t.sol";

contract TellerTest is BaseSetup {
    event ControllerSet(address indexed controllerAddress);
    event TimelockSet(address indexed timelockAddress);
    event CallerApproved(address indexed caller);
    event CallerRevoked(address indexed caller);
    event PHOCeilingSet(uint256 ceiling);

    function setUp() public {
        _approveCaller(owner);
    }

    /// mintPHO()

    function testMintPHO() public {
        uint256 ownerPHOBalanceBefore = pho.balanceOf(owner);
        uint256 tellerMintingBalanceBefore = teller.totalPHOMinted();
        uint256 phoTotalSupplyBefore = pho.totalSupply();
        uint256 approvedMinterTotalMintedBefore = teller.mintingBalances(owner);

        vm.prank(owner);
        teller.mintPHO(owner, tenThousand_d18);

        uint256 ownerPHOBalanceAfter = pho.balanceOf(owner);
        uint256 tellerMintingBalanceAfter = teller.totalPHOMinted();
        uint256 phoTotalSupplyAfter = pho.totalSupply();
        uint256 approvedMinterTotalMintedAfter = teller.mintingBalances(owner);

        assertEq(ownerPHOBalanceAfter, ownerPHOBalanceBefore + tenThousand_d18);
        assertEq(tellerMintingBalanceAfter, tellerMintingBalanceBefore + tenThousand_d18);
        assertEq(phoTotalSupplyAfter, phoTotalSupplyBefore + tenThousand_d18);
        assertEq(approvedMinterTotalMintedAfter, approvedMinterTotalMintedBefore + tenThousand_d18);
    }

    function testCannotMintPHONotApproved() public {
        vm.expectRevert("Teller: caller is not approved");
        vm.prank(user1);
        teller.mintPHO(owner, tenThousand_d18);
    }

    function testCannotMintPhoZeroAddress() public {
        vm.expectRevert("Teller: zero address detected");
        vm.prank(owner);
        teller.mintPHO(address(0), tenThousand_d18);
    }

    function testCannotMintPHOCeilingReached() public {
        uint256 phoCeiling = teller.phoCeiling();
        vm.expectRevert("Teller: ceiling reached");
        vm.prank(owner);
        teller.mintPHO(user1, phoCeiling + tenThousand_d18);
    }

    /// approveCaller()

    function testApproveCaller() public {
        vm.expectEmit(true, false, false, true);
        emit CallerApproved(address(103));
        vm.prank(owner);
        teller.approveCaller(address(103));
        assertTrue(teller.approvedCallers(address(103)));
    }

    function testCannotApproveCallerNotAllowed() public {
        vm.expectRevert("Teller: Not the owner, controller, or the governance timelock");
        teller.approveCaller(address(103));
    }

    function testCannotApproveCallerAddressZero() public {
        vm.expectRevert("Teller: zero address detected");
        vm.prank(owner);
        teller.approveCaller(address(0));
    }

    function testCannotApproveCallerAlreadyApproved() public {
        vm.expectRevert("Teller: caller is already approved");
        vm.prank(owner);
        teller.approveCaller(owner);
    }

    /// revokeCaller()

    function testRevokeCaller() public {
        vm.expectEmit(true, false, false, true);
        emit CallerRevoked(owner);
        vm.prank(owner);
        teller.revokeCaller(owner);
        assertFalse(teller.approvedCallers(owner));
    }

    function testCannotRevokeCallerNotAllowed() public {
        vm.expectRevert("Teller: Not the owner, controller, or the governance timelock");
        teller.revokeCaller(address(103));
    }

    function testCannotRevokeCallerAddressZero() public {
        vm.expectRevert("Teller: zero address detected");
        vm.prank(owner);
        teller.revokeCaller(address(0));
    }

    function testCannotRevokeCallerNotApproved() public {
        vm.expectRevert("Teller: caller is not approved");
        vm.prank(owner);
        teller.revokeCaller(user1);
    }

    /// setPHOCeiling()

    function setPHOCeiling() public {
        vm.expectEmit(true, false, false, true);
        emit PHOCeilingSet(tenThousand_d18);
        vm.prank(owner);
        teller.setPHOCeiling(tenThousand_d18);
        assertEq(teller.phoCeiling(), tenThousand_d18);
    }

    function testCannotSetPhoCeilingNotAllowed() public {
        vm.expectRevert("Teller: Not the owner, controller, or the governance timelock");
        vm.prank(user1);
        teller.setPHOCeiling(tenThousand_d18);
    }

    function testCannotSetPhoCeilingToZero() public {
        vm.expectRevert("Teller: new ceiling cannot be 0");
        vm.prank(owner);
        teller.setPHOCeiling(0);
    }

    function testCannotSetPHOCeilingSameValue() public {
        uint256 currentCeiling = teller.phoCeiling();
        vm.expectRevert("Teller: same ceiling value detected");
        vm.prank(owner);
        teller.setPHOCeiling(currentCeiling);
    }

    /// setController()

    function testSetController() public {
        vm.startPrank(owner);
        address initialController = pho.controllerAddress();
        vm.expectEmit(false, false, false, true);
        emit ControllerSet(user1);
        pho.setController(user1);

        assertTrue(initialController != pho.controllerAddress());
        assertEq(pho.controllerAddress(), user1);
        vm.stopPrank();
    }

    function testCannotSetControllerAddressZero() public {
        vm.expectRevert("Teller: zero address detected");
        vm.prank(owner);
        teller.setController(address(0));
    }

    function testCannotSetControllerNotAllowed() public {
        vm.expectRevert("Teller: Not the owner, controller, or the governance timelock");
        vm.prank(user1);
        teller.setController(address(0));
    }

    function testCannotSetControllerSameAddress() public {
        address currentController = teller.controllerAddress();
        vm.expectRevert("Teller: same address detected");
        vm.prank(owner);
        teller.setController(currentController);
    }

    /// setTimelock()

    function testSetTimelock() public {
        vm.startPrank(owner);
        address initialTimelock = pho.controllerAddress();
        vm.expectEmit(false, false, false, true);
        emit TimelockSet(user1);
        teller.setTimelock(user1);

        assertTrue(initialTimelock != teller.timelockAddress());
        assertEq(teller.timelockAddress(), user1);
        vm.stopPrank();
    }

    function testCannotSetTimelockAddressZero() public {
        vm.expectRevert("Teller: zero address detected");
        vm.prank(owner);
        teller.setTimelock(address(0));
    }

    function testCannotSetTimelockNotAllowed() public {
        vm.expectRevert("Teller: Not the owner, controller, or the governance timelock");
        vm.prank(user1);
        teller.setTimelock(address(0));
    }

    function _approveCaller(address toApprove) private {
        vm.prank(owner);
        teller.approveCaller(toApprove);
    }

    function testCannotSetTimelockSameAddress() public {
        address currentTimelock = teller.timelockAddress();
        vm.expectRevert("Teller: same address detected");
        vm.prank(owner);
        teller.setTimelock(currentTimelock);
    }
}
