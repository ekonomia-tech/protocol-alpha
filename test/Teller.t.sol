// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/contracts/TON.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./BaseSetup.t.sol";

contract TellerTest is BaseSetup {
    event ControllerSet(address indexed controllerAddress);
    event TimelockSet(address indexed timelockAddress);
    event CallerApproved(address indexed caller, uint256 newCeiling);
    event CallerRevoked(address indexed caller);
    event CallerCeilingModified(address indexed caller, uint256 newCeiling);
    event PHOCeilingSet(uint256 ceiling);

    function setUp() public {
        _approveCaller(owner, 2 * tenThousand_d18);
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
        uint256 mintCeiling = teller.mintCeiling();
        vm.expectRevert("Teller: ceiling reached");
        vm.prank(owner);
        teller.mintPHO(user1, mintCeiling + tenThousand_d18);
    }

    function testCannotMintPHOCallerCeilingReached() public {
        uint256 callerCeiling = teller.whitelist(owner);
        vm.expectRevert("Teller: caller ceiling reached");
        vm.prank(owner);
        teller.mintPHO(owner, callerCeiling + 1);
    }

    /// approveCaller()

    function testApproveCaller() public {
        vm.expectEmit(true, false, false, true);
        emit CallerApproved(address(103), tenThousand_d18);
        vm.prank(owner);
        teller.approveCaller(address(103), tenThousand_d18);
        assertEq(teller.whitelist(address(103)), tenThousand_d18);
    }

    function testCannotApproveCallerNotAllowed() public {
        vm.expectRevert("Ownable: caller is not the owner");
        teller.approveCaller(address(103), tenThousand_d18);
    }

    function testCannotApproveCallerAddressZero() public {
        vm.expectRevert("Teller: zero address detected");
        vm.prank(owner);
        teller.approveCaller(address(0), tenThousand_d18);
    }

    function testCannotApproveCallerAlreadyApproved() public {
        vm.expectRevert("Teller: caller is already approved");
        vm.prank(owner);
        teller.approveCaller(owner, tenThousand_d18);
    }

    /// revokeCaller()

    function testRevokeCaller() public {
        vm.expectEmit(true, false, false, true);
        emit CallerRevoked(owner);
        vm.prank(owner);
        teller.revokeCaller(owner);
        assertTrue(teller.whitelist(owner) == 0);
    }

    function testCannotRevokeCallerNotAllowed() public {
        vm.expectRevert("Ownable: caller is not the owner");
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

    /// modifyCallerCeiling()

    function testModifyCallerCeiling() public {
        _approveCaller(user1, tenThousand_d18);
        uint256 newCeiling = 2 * tenThousand_d18;
        vm.prank(user1);
        teller.mintPHO(owner, tenThousand_d18);
        vm.expectEmit(true, false, false, true);
        emit CallerCeilingModified(user1, newCeiling);
        vm.prank(owner);
        teller.modifyCallerCeiling(user1, newCeiling);
    }

    function testCannotModifyCallerCeilingNotAllowed() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(user1);
        teller.modifyCallerCeiling(owner, 3 * tenThousand_d18);
    }

    function testCannotModifyCallerCeilingZeroAddress() public {
        vm.expectRevert("Teller: zero address detected");
        vm.prank(owner);
        teller.modifyCallerCeiling(address(0), 0);
    }

    function testCannotModifyCallerCeilingNotApproved() public {
        vm.expectRevert("Teller: caller is not approved");
        vm.prank(owner);
        teller.modifyCallerCeiling(user1, tenThousand_d18);
    }

    function testCannotModifyCallerCeilingTooLow() public {
        _approveCaller(user1, tenThousand_d18);
        uint256 newCeiling = teller.whitelist(user1) - 1;
        vm.prank(user1);
        teller.mintPHO(owner, tenThousand_d18);
        vm.expectRevert("Teller: new ceiling too low");
        vm.prank(owner);
        teller.modifyCallerCeiling(user1, newCeiling);
    }

    /// setPHOCeiling()

    function setPHOCeiling() public {
        vm.expectEmit(true, false, false, true);
        emit PHOCeilingSet(tenThousand_d18);
        vm.prank(owner);
        teller.setPHOCeiling(tenThousand_d18);
        assertEq(teller.mintCeiling(), tenThousand_d18);
    }

    function testCannotSetPhoCeilingNotAllowed() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(user1);
        teller.setPHOCeiling(tenThousand_d18);
    }

    function testCannotSetPhoCeilingToZero() public {
        vm.expectRevert("Teller: new ceiling cannot be 0");
        vm.prank(owner);
        teller.setPHOCeiling(0);
    }

    function testCannotSetPHOCeilingSameValue() public {
        uint256 currentCeiling = teller.mintCeiling();
        vm.expectRevert("Teller: same ceiling value detected");
        vm.prank(owner);
        teller.setPHOCeiling(currentCeiling);
    }

    function testCannotSetPHOCeilingMintedMoreThanNewCeiling() public {
        uint256 currentCeiling = teller.mintCeiling();
        vm.startPrank(owner);
        teller.modifyCallerCeiling(owner, currentCeiling);
        teller.mintPHO(user1, currentCeiling);
        vm.expectRevert("Teller: new ceiling too low");
        teller.setPHOCeiling(currentCeiling - 2000);
        vm.stopPrank();
    }

    /// private functions

    function _approveCaller(address caller, uint256 ceiling) private {
        vm.prank(owner);
        teller.approveCaller(caller, ceiling);
    }
}
