// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseSetup.t.sol";

// error Unauthorized();

contract PHOTest is BaseSetup {
    event TellerSet(address indexed teller);

    function setUp() public {
        vm.prank(address(teller));
        pho.mint(user1, TEN_THOUSAND_D18);
    }
    /// setup tests

    function testPHOConstructor() public {
        assertEq(pho.balanceOf(user1), TEN_THOUSAND_D18);
        assertEq(pho.name(), "PHO");
        assertEq(pho.symbol(), "PHO");
        assertEq(pho.decimals(), 18);
    }

    /// allowance() + approve() tests

    // helper
    function setupAllowance(address _user, address _spender, uint256 _amount) public {
        vm.prank(_user);
        pho.approve(_spender, _amount);
    }

    /// mint() tests

    function testMint() public {
        uint256 user1BalanceBefore = pho.balanceOf(user1);
        uint256 totalSupplyBefore = pho.totalSupply();

        vm.prank(address(teller));
        pho.mint(user1, ONE_HUNDRED_D18 * 5);

        uint256 totalSupplyAfter = pho.totalSupply();
        uint256 user1BalanceAfter = pho.balanceOf(user1);

        assertEq(totalSupplyAfter, totalSupplyBefore + ONE_HUNDRED_D18 * 5);
        assertEq(user1BalanceAfter, user1BalanceBefore + ONE_HUNDRED_D18 * 5);
    }

    function testCannotMintNotTeller() public {
        vm.expectRevert("PHO: caller is not the teller");
        vm.prank(user1);
        pho.mint(user1, ONE_HUNDRED_D18 * 5);
    }

    /// setTeller()

    function setTeller() public {
        vm.startPrank(owner);
        address initialTeller = pho.teller();
        vm.expectEmit(true, false, false, true);
        emit TellerSet(owner);
        pho.setTeller(owner);

        assertTrue(initialTeller != pho.teller());
        assertEq(pho.teller(), owner);
        vm.stopPrank();
    }

    function testCannotSetTellerAddressZero() public {
        vm.expectRevert("PHO: zero address detected");
        vm.prank(owner);
        pho.setTeller(address(0));
    }

    function testCannotSetTellerNotAllowed() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(user1);
        pho.setTeller(address(0));
    }

    function testCannotSetTellerSameAddress() public {
        address currentTeller = pho.teller();
        vm.expectRevert("PHO: same address detected");
        vm.prank(owner);
        pho.setTeller(currentTeller);
    }
}
