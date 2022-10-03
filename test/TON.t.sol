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
        ton.transfer(user1, TEN_THOUSAND_D18);
    }

    function testConstructor() public {
        assertEq(ton.totalSupply(), GENESIS_SUPPLY_D18);
        assertEq(ton.balanceOf(owner), GENESIS_SUPPLY_D18 - TEN_THOUSAND_D18);
    }
}
