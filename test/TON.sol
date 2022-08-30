// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/contracts/TON.sol";
import "../src/contracts/PHO.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./BaseSetup.t.sol";

contract TONTest is BaseSetup {
    event PHOAddressSet(address newAddress);

    function setUp() public {}

    function testConstructor() public {
        assertEq(ton.oracle_address(), address(priceOracle));
        assertEq(ton.timelock_address(), timelock_address);
    }

    function testSetOracleAddress() public {
        vm.prank(owner);
        ton.setOracle(user1);
        assertEq(user1, ton.oracle_address());
    }

    function testCannotSetOracleBadOrigin() public {
        vm.expectRevert("You are not an owner or the governance timelock");
        vm.prank(user2);
        ton.setOracle(user2);
    }

    function testCannotSetOracleZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("Zero address detected");
        ton.setOracle(address(0));
    }

    function testSetTimelock() public {
        vm.prank(owner);
        ton.setTimelock(user2);
        assertEq(user2, ton.timelock_address());
    }

    function testCannotSetTimelockBadOrigin() public {
        vm.expectRevert("You are not an owner or the governance timelock");
        vm.prank(user1);
        ton.setTimelock(user1);
    }

    function testCannotSetTImelockZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("Timelock address cannot be 0");
        ton.setTimelock(address(0));
    }

    function testSetPHOAddress() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit PHOAddressSet(address(pho));
        ton.setPHOAddress(address(pho));
        assertEq(address(pho), address(ton.pho()));
    }

    function testCannotSetPHOAddressBadOrigin() public {
        vm.expectRevert("You are not an owner or the governance timelock");
        vm.prank(user1);
        ton.setPHOAddress(user1);
    }

    function testCannotSetPHOAddressZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("Zero address detected");
        ton.setPHOAddress(address(0));
    }

    function testPoolMint() public {
        uint256 mintAmount = one_d18;
        _addPHOPool(user1);

        vm.prank(user1);
        ton.pool_mint(user2, mintAmount);
    }

    function testCannotPoolMint() public {
        uint256 mintAmount = one_d18;
        // this time msg.sender is not a pool, wil fail on modifier
        vm.expectRevert("Only pho pools can mint or burn TON");
        ton.pool_mint(user2, mintAmount);
    }

    function testPoolBurn() public {
        uint256 mintAmount = one_d18 * 2;
        uint256 burnAmount = one_d18;

        _addPHOPool(user1);

        vm.prank(user1);
        ton.pool_mint(user2, mintAmount);
        assertEq(ton.balanceOf(user2), mintAmount);

        vm.startPrank(user2);
        ton.approve(user1, burnAmount);
        assertEq(ton.allowance(user2, user1), burnAmount);
        vm.stopPrank();

        vm.prank(user1);
        ton.pool_burn_from(user2, burnAmount);
    }

    function testCannotPoolBurn() public {
        uint256 burnAmount = one_d18;
        // do not impose as pool
        vm.expectRevert("Only pho pools can mint or burn TON");
        ton.pool_burn_from(user2, burnAmount);
    }

    /// Helpers

    function _addPHOPool(address _pool) private {
        vm.startPrank(owner);
        pho.addPool(_pool);
        vm.stopPrank();
    }
}
