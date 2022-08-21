// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/contracts/Share.sol";
import "../src/contracts/EUSD.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract ShareTest is Test {

    Share public share;
    EUSD public eusd;

    address public randomAccount1 = 0x701ded139b267F9Df781700Eb97337B07cFdDdd8;
    address public randomAccount2 = 0xDc516b17761a2521993823b1f1d274aD90B29E1d;
    address owner;

    event EUSDAddressSet(address newAddress);

    function setUp() public {
        vm.prank(msg.sender);
        owner = msg.sender;
        eusd = new EUSD("EUSD", "EUSD", owner, owner);
        share = new Share("Share", "SHARE",owner, owner);
        share.setEUSDAddress(address(eusd));
    }

    function testConstructor() public {
        assertEq(share.oracle_address(), owner);
        assertEq(share.timelock_address(), owner);
    }

    function testSetOracleAddress() public {
        share.setOracle(randomAccount1);
        assertEq(randomAccount1, share.oracle_address());
    }

    function testCannotSetOracleBadOrigin() public {
        vm.expectRevert("You are not an owner or the governance timelock");
        vm.prank(randomAccount2);
        share.setOracle(randomAccount2);
    }

    function testCannotSetOracleZeroAddress() public {
        vm.expectRevert("Zero address detected");
        share.setOracle(address(0));
    }

    function testSetTimelock() public {
        share.setTimelock(randomAccount2);
        assertEq(randomAccount2, share.timelock_address());
    }

    function testCannotSetTimelockBadOrigin() public {
        vm.expectRevert("You are not an owner or the governance timelock");
        vm.prank(randomAccount1);
        share.setTimelock(randomAccount1);
    }

    function testCannotSetTImelockZeroAddress() public {
        vm.expectRevert("Timelock address cannot be 0");
        share.setTimelock(address(0));
    }

    function testSetEUSDAddress() public {
        vm.expectEmit(true, false, false, false);
        emit EUSDAddressSet(address(eusd));
        share.setEUSDAddress(address(eusd));
        assertEq(address(eusd), address(share.eusd()));
    }

    function testCannotSetEUSDAddressBadOrigin() public {
        vm.expectRevert("You are not an owner or the governance timelock");
        vm.prank(randomAccount1);
        share.setEUSDAddress(randomAccount1);
    }

    function testCannotSetSetEUSDAddressZeroAddress() public {
        vm.expectRevert("Zero address detected");
        share.setEUSDAddress(address(0));
    }

    function testPoolMint() public {
        uint256 mintAmount = 1e18;
        _addEusdPool(randomAccount1);
       
        vm.prank(randomAccount1);
        share.pool_mint(randomAccount2, mintAmount);
    }

    function testCannotPoolMint() public {
        uint256 mintAmount = 1e18;
        // this time msg.sender is not a pool, wil fail on modifier
        vm.expectRevert("Only eusd pools can mint or burn SHARE");
        share.pool_mint(randomAccount2, mintAmount);
    }

    function testPoolBurn() public {
        uint256 mintAmount = 2e18;
        uint256 burnAmount = 1e18;

        _addEusdPool(randomAccount1);

        vm.prank(randomAccount1);
        share.pool_mint(randomAccount2, mintAmount);
        assertEq(share.balanceOf(randomAccount2), mintAmount);

        vm.startPrank(randomAccount2);
        share.approve(randomAccount1, burnAmount);
        assertEq(share.allowance(randomAccount2, randomAccount1), burnAmount);
        vm.stopPrank();
        
        vm.prank(randomAccount1);
        share.pool_burn_from(randomAccount2, burnAmount);
    }

    function testCannotPoolBurn() public {
        uint256 burnAmount = 1e18;
        // do not impose as pool
        vm.expectRevert("Only eusd pools can mint or burn SHARE");
        share.pool_burn_from(randomAccount2, burnAmount);
    }

    /// Helpers

    function _addEusdPool(address _pool) private {
        vm.startPrank(owner);
        eusd.addPool(_pool);
        vm.stopPrank();
    }

}
