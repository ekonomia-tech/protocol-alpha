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

    function setUp() public {
        vm.prank(owner);
        ton.transfer(user1, tenThousand_d18);
    }

    function testConstructor() public {
        assertEq(ton.totalSupply(), GENESIS_SUPPLY_d18);
        assertEq(ton.balanceOf(owner), GENESIS_SUPPLY_d18 - tenThousand_d18);
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
}
