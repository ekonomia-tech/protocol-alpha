// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/contracts/TON.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./BaseSetup.t.sol";

contract TellerTest is BaseSetup {
    event ControllerSet(address controllerAddress);
    event TimelockSet(address timelockAddress);
    event CallerApproved(address caller);
    event CallerRevoked(address caller);
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
        assertTrue(teller.approved(address(103)));
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

    /// revokeCaller()

    function testRevokeCaller() public {
        vm.expectEmit(true, false, false, true);
        emit CallerRevoked(owner);
        vm.prank(owner);
        teller.revokeCaller(owner);
        assertFalse(teller.approved(owner));
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

    function testCannotSetPHOCeilingTo0() public {
        vm.expectRevert("Teller: new ceiling cannot be 0");
        vm.prank(owner);
        teller.setPHOCeiling(0);
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
        vm.expectRevert("PHO: zero address detected");
        vm.prank(owner);
        pho.setController(address(0));
    }

    function testCannotSetControllerNotAllowed() public {
        vm.expectRevert("PHO: Not the owner, controller, or the governance timelock");
        vm.prank(user1);
        pho.setController(address(0));
    }

    /// setTimelock()

    function testSetTimelock() public {
        vm.startPrank(owner);
        address initialTimelock = pho.controllerAddress();
        vm.expectEmit(false, false, false, true);
        emit TimelockSet(user1);
        pho.setTimelock(user1);

        assertTrue(initialTimelock != pho.timelockAddress());
        assertEq(pho.timelockAddress(), user1);
        vm.stopPrank();
    }

    function testCannotSetTimelockAddressZero() public {
        vm.expectRevert("PHO: zero address detected");
        vm.prank(owner);
        pho.setTimelock(address(0));
    }

    function testCannotSetTimelockNotAllowed() public {
        vm.expectRevert("PHO: Not the owner, controller, or the governance timelock");
        vm.prank(user1);
        pho.setTimelock(address(0));
    }

    function _approveCaller(address toApprove) private {
        vm.prank(owner);
        teller.approveCaller(toApprove);
    }
}
