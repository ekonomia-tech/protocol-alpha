// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseSetup.t.sol";

// error Unauthorized();

contract PHOTest is BaseSetup {
    event KernelSet(address indexed kernel);

    function setUp() public {
        vm.prank(address(kernel));
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

        vm.prank(address(kernel));
        pho.mint(user1, ONE_HUNDRED_D18 * 5);

        uint256 totalSupplyAfter = pho.totalSupply();
        uint256 user1BalanceAfter = pho.balanceOf(user1);

        assertEq(totalSupplyAfter, totalSupplyBefore + ONE_HUNDRED_D18 * 5);
        assertEq(user1BalanceAfter, user1BalanceBefore + ONE_HUNDRED_D18 * 5);
    }

    function testCannotMintNotKernel() public {
        vm.expectRevert("PHO: caller is not the kernel");
        vm.prank(user1);
        pho.mint(user1, ONE_HUNDRED_D18 * 5);
    }

    /// setKernel()

    function setKernel() public {
        vm.startPrank(owner);
        address initialKernel = pho.kernel();
        vm.expectEmit(true, false, false, true);
        emit KernelSet(owner);
        pho.setKernel(owner);

        assertTrue(initialKernel != pho.kernel());
        assertEq(pho.kernel(), owner);
        vm.stopPrank();
    }

    function testCannotSetKernelAddressZero() public {
        vm.expectRevert("PHO: zero address detected");
        vm.prank(owner);
        pho.setKernel(address(0));
    }

    function testCannotSetKernelNotAllowed() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(user1);
        pho.setKernel(address(0));
    }

    function testCannotSetKernelSameAddress() public {
        address currentKernel = pho.kernel();
        vm.expectRevert("PHO: same address detected");
        vm.prank(owner);
        pho.setKernel(currentKernel);
    }
}
