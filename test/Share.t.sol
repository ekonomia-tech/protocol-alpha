// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "contracts/Share.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";



contract ShareTest is Test {

    Share public share;

    function setUp() public {
        vm.prank(msg.sender);
        share = new Share("Share", "SHARE", msg.sender, msg.sender);
    }

    function testUser() public {
        console.log("something");
    }
}
