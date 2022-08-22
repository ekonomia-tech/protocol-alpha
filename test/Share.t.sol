// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/contracts/Share.sol";
import "../src/contracts/EUSD.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./BaseSetup.t.sol";

contract ShareTest is BaseSetup {
    event EUSDAddressSet(address newAddress);

    function setUp() public { }

    function testConstructor() public {
        assertEq(share.oracle_address(), address(priceOracle));
        assertEq(share.timelock_address(), timelock_address);
    }

    function testSetOracleAddress() public {
        vm.prank(owner);
        share.setOracle(user1);
        assertEq(user1, share.oracle_address());
    }

    function testCannotSetOracleBadOrigin() public {
        vm.expectRevert("You are not an owner or the governance timelock");
        vm.prank(user2);
        share.setOracle(user2);
    }

    function testCannotSetOracleZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("Zero address detected");
        share.setOracle(address(0));
    }

    function testSetTimelock() public {
        vm.prank(owner);
        share.setTimelock(user2);
        assertEq(user2, share.timelock_address());
    }

    function testCannotSetTimelockBadOrigin() public {
        vm.expectRevert("You are not an owner or the governance timelock");
        vm.prank(user1);
        share.setTimelock(user1);
    }

    function testCannotSetTImelockZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("Timelock address cannot be 0");
        share.setTimelock(address(0));
    }

    function testSetEUSDAddress() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit EUSDAddressSet(address(eusd));
        share.setEUSDAddress(address(eusd));
        assertEq(address(eusd), address(share.eusd()));
    }

    function testCannotSetEUSDAddressBadOrigin() public {
        vm.expectRevert("You are not an owner or the governance timelock");
        vm.prank(user1);
        share.setEUSDAddress(user1);
    }

    function testCannotSetEUSDAddressZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("Zero address detected");
        share.setEUSDAddress(address(0));
    }

    function testPoolMint() public {
        uint256 mintAmount = one_d18;
        _addEusdPool(user1);

        vm.prank(user1);
        share.pool_mint(user2, mintAmount);
    }

    function testCannotPoolMint() public {
        uint256 mintAmount = one_d18;
        // this time msg.sender is not a pool, wil fail on modifier
        vm.expectRevert("Only eusd pools can mint or burn SHARE");
        share.pool_mint(user2, mintAmount);
    }

    function testPoolBurn() public {
        uint256 mintAmount = one_d18 * 2;
        uint256 burnAmount = one_d18;

        _addEusdPool(user1);

        vm.prank(user1);
        share.pool_mint(user2, mintAmount);
        assertEq(share.balanceOf(user2), mintAmount);

        vm.startPrank(user2);
        share.approve(user1, burnAmount);
        assertEq(share.allowance(user2, user1), burnAmount);
        vm.stopPrank();

        vm.prank(user1);
        share.pool_burn_from(user2, burnAmount);
    }

    function testCannotPoolBurn() public {
        uint256 burnAmount = one_d18;
        // do not impose as pool
        vm.expectRevert("Only eusd pools can mint or burn SHARE");
        share.pool_burn_from(user2, burnAmount);
    }

    /// Helpers

    function _addEusdPool(address _pool) private {
        vm.startPrank(owner);
        eusd.addPool(_pool);
        vm.stopPrank();
    }
}
