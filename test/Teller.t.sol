// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/contracts/TON.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./BaseSetup.t.sol";

contract TellerTest is BaseSetup {
// event ControllerSet(address indexed controllerAddress);
// event TimelockSet(address indexed timelockAddress);
// event CallerWhitelisted(address indexed caller, uint256 newCeiling);
// event CallerRevoked(address indexed caller);
// event CallerCeilingModified(address indexed caller, uint256 newCeiling);
// event PHOCeilingSet(uint256 ceiling);

// function setUp() public {
//     _whitelistCaller(owner, 2 * TEN_THOUSAND_D18);
// }

// /// mintPHO()

// function testMintPHO() public {
//     uint256 ownerPHOBalanceBefore = pho.balanceOf(owner);
//     uint256 tellerMintingBalanceBefore = teller.totalPHOMinted();
//     uint256 phoTotalSupplyBefore = pho.totalSupply();
//     uint256 whitelistedMinterTotalMintedBefore = teller.mintingBalances(owner);

//     vm.prank(owner);
//     teller.mintPHO(owner, TEN_THOUSAND_D18);

//     uint256 ownerPHOBalanceAfter = pho.balanceOf(owner);
//     uint256 tellerMintingBalanceAfter = teller.totalPHOMinted();
//     uint256 phoTotalSupplyAfter = pho.totalSupply();
//     uint256 whitelistedMinterTotalMintedAfter = teller.mintingBalances(owner);

//     assertEq(ownerPHOBalanceAfter, ownerPHOBalanceBefore + TEN_THOUSAND_D18);
//     assertEq(tellerMintingBalanceAfter, tellerMintingBalanceBefore + TEN_THOUSAND_D18);
//     assertEq(phoTotalSupplyAfter, phoTotalSupplyBefore + TEN_THOUSAND_D18);
//     assertEq(
//         whitelistedMinterTotalMintedAfter, whitelistedMinterTotalMintedBefore + TEN_THOUSAND_D18
//     );
// }

// function testCannotMintPHONotApproved() public {
//     vm.expectRevert("Teller: caller is not approved");
//     vm.prank(user1);
//     teller.mintPHO(owner, TEN_THOUSAND_D18);
// }

// function testCannotMintPhoZeroAddress() public {
//     vm.expectRevert("Teller: zero address detected");
//     vm.prank(owner);
//     teller.mintPHO(address(0), TEN_THOUSAND_D18);
// }

// function testCannotMintPHOCeilingReached() public {
//     uint256 mintCeiling = teller.mintCeiling();
//     vm.expectRevert("Teller: ceiling reached");
//     vm.prank(owner);
//     teller.mintPHO(user1, mintCeiling + TEN_THOUSAND_D18);
// }

// function testCannotMintPHOCallerCeilingReached() public {
//     uint256 callerCeiling = teller.whitelist(owner);
//     vm.expectRevert("Teller: caller ceiling reached");
//     vm.prank(owner);
//     teller.mintPHO(owner, callerCeiling + 1);
// }

// /// whitelistCaller()

// function testWhitelistCaller() public {
//     vm.expectEmit(true, false, false, true);
//     emit CallerWhitelisted(address(103), TEN_THOUSAND_D18);
//     vm.prank(owner);
//     teller.whitelistCaller(address(103), TEN_THOUSAND_D18);
//     assertEq(teller.whitelist(address(103)), TEN_THOUSAND_D18);
// }

// function testCannotWhitelistCallerNotAllowed() public {
//     vm.expectRevert("Ownable: caller is not the owner");
//     teller.whitelistCaller(address(103), TEN_THOUSAND_D18);
// }

// function testCannotWhitelistCallerAddressZero() public {
//     vm.expectRevert("Teller: zero address detected");
//     vm.prank(owner);
//     teller.whitelistCaller(address(0), TEN_THOUSAND_D18);
// }

// function testCannotWhitelistCallerAlreadyApproved() public {
//     vm.expectRevert("Teller: caller is already approved");
//     vm.prank(owner);
//     teller.whitelistCaller(owner, TEN_THOUSAND_D18);
// }

// /// revokeCaller()

// function testRevokeCaller() public {
//     vm.expectEmit(true, false, false, true);
//     emit CallerRevoked(owner);
//     vm.prank(owner);
//     teller.revokeCaller(owner);
//     assertTrue(teller.whitelist(owner) == 0);
// }

// function testCannotRevokeCallerNotAllowed() public {
//     vm.expectRevert("Ownable: caller is not the owner");
//     teller.revokeCaller(address(103));
// }

// function testCannotRevokeCallerAddressZero() public {
//     vm.expectRevert("Teller: zero address detected");
//     vm.prank(owner);
//     teller.revokeCaller(address(0));
// }

// function testCannotRevokeCallerNotApproved() public {
//     vm.expectRevert("Teller: caller is not approved");
//     vm.prank(owner);
//     teller.revokeCaller(user1);
// }

// /// modifyCallerCeiling()

// function testModifyCallerCeiling() public {
//     _whitelistCaller(user1, TEN_THOUSAND_D18);
//     uint256 newCeiling = 2 * TEN_THOUSAND_D18;
//     vm.prank(user1);
//     teller.mintPHO(owner, TEN_THOUSAND_D18);
//     vm.expectEmit(true, false, false, true);
//     emit CallerCeilingModified(user1, newCeiling);
//     vm.prank(owner);
//     teller.modifyCallerCeiling(user1, newCeiling);
// }

// function testCannotModifyCallerCeilingNotAllowed() public {
//     vm.expectRevert("Ownable: caller is not the owner");
//     vm.prank(user1);
//     teller.modifyCallerCeiling(owner, 3 * TEN_THOUSAND_D18);
// }

// function testCannotModifyCallerCeilingZeroAddress() public {
//     vm.expectRevert("Teller: zero address detected");
//     vm.prank(owner);
//     teller.modifyCallerCeiling(address(0), 0);
// }

// function testCannotModifyCallerCeilingNotApproved() public {
//     vm.expectRevert("Teller: caller is not approved");
//     vm.prank(owner);
//     teller.modifyCallerCeiling(user1, TEN_THOUSAND_D18);
// }

// function testCannotModifyCallerCeilingTooLow() public {
//     _whitelistCaller(user1, TEN_THOUSAND_D18);
//     uint256 newCeiling = teller.whitelist(user1) - 1;
//     vm.prank(user1);
//     teller.mintPHO(owner, TEN_THOUSAND_D18);
//     vm.expectRevert("Teller: new ceiling too low");
//     vm.prank(owner);
//     teller.modifyCallerCeiling(user1, newCeiling);
// }

// /// setPHOCeiling()

// function setPHOCeiling() public {
//     vm.expectEmit(true, false, false, true);
//     emit PHOCeilingSet(TEN_THOUSAND_D18);
//     vm.prank(owner);
//     teller.setPHOCeiling(TEN_THOUSAND_D18);
//     assertEq(teller.mintCeiling(), TEN_THOUSAND_D18);
// }

// function testCannotSetPhoCeilingNotAllowed() public {
//     vm.expectRevert("Ownable: caller is not the owner");
//     vm.prank(user1);
//     teller.setPHOCeiling(TEN_THOUSAND_D18);
// }

// function testCannotSetPhoCeilingToZero() public {
//     vm.expectRevert("Teller: new ceiling cannot be 0");
//     vm.prank(owner);
//     teller.setPHOCeiling(0);
// }

// function testCannotSetPHOCeilingSameValue() public {
//     uint256 currentCeiling = teller.mintCeiling();
//     vm.expectRevert("Teller: same ceiling value detected");
//     vm.prank(owner);
//     teller.setPHOCeiling(currentCeiling);
// }

// function testCannotSetPHOCeilingMintedMoreThanNewCeiling() public {
//     uint256 currentCeiling = teller.mintCeiling();
//     vm.startPrank(owner);
//     teller.modifyCallerCeiling(owner, currentCeiling);
//     teller.mintPHO(user1, currentCeiling);
//     vm.expectRevert("Teller: new ceiling too low");
//     teller.setPHOCeiling(currentCeiling - 2000);
//     vm.stopPrank();
// }

// /// private functions

// function _whitelistCaller(address caller, uint256 ceiling) private {
//     vm.prank(owner);
//     teller.whitelistCaller(caller, ceiling);
// }
}
