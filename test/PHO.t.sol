// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseSetup.t.sol";

// error Unauthorized();

contract PHOTest is BaseSetup {
    event PHOBurned(address indexed from, address indexed burnCaller, uint256 amount);
    event PHOMinted(address indexed mintCaller, address indexed to, uint256 amount);
    event TellerSet(address indexed teller);
    event ControllerSet(address indexed controllerAddress);
    event TimelockSet(address indexed timelockAddress);

    function setUp() public {
        vm.prank(address(teller));
        pho.mint(user1, tenThousand_d18);
    }
    /// setup tests

    function testPHOConstructor() public {
        assertEq(pho.controllerAddress(), owner);
        assertEq(pho.balanceOf(user1), tenThousand_d18);
        assertEq(pho.name(), "Pho");
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

        vm.expectEmit(true, true, false, true);
        emit PHOMinted(address(teller), user1, fiveHundred_d18);
        vm.prank(address(teller));
        pho.mint(user1, fiveHundred_d18);

        uint256 totalSupplyAfter = pho.totalSupply();
        uint256 user1BalanceAfter = pho.balanceOf(user1);

        assertEq(totalSupplyAfter, totalSupplyBefore + fiveHundred_d18);
        assertEq(user1BalanceAfter, user1BalanceBefore + fiveHundred_d18);
    }

    function testCannotMintNotTeller() public {
        vm.expectRevert("PHO: caller is not the teller");
        vm.prank(user1);
        pho.mint(user1, fiveHundred_d18);
    }

    /// burn()

    function testBurn() public {
        uint256 userBalanceBefore = pho.balanceOf(user1);
        uint256 totalSupplyBefore = pho.totalSupply();

        vm.prank(user1);
        pho.approve(owner, fiveHundred_d18);

        vm.expectEmit(true, true, false, true);
        emit PHOBurned(user1, owner, fiveHundred_d18);
        vm.prank(owner);
        pho.burn(user1, fiveHundred_d18);

        uint256 userBalanceAfter = pho.balanceOf(user1);
        uint256 totalSupplyAfter = pho.totalSupply();

        assertEq(userBalanceBefore, userBalanceAfter + fiveHundred_d18);
        assertEq(totalSupplyBefore, totalSupplyAfter + fiveHundred_d18);
    }

    /// setTeller()

    function setTeller() public {
        vm.startPrank(owner);
        address initialTeller = pho.tellerAddress();
        vm.expectEmit(true, false, false, true);
        emit TellerSet(owner);
        pho.setTeller(owner);

        assertTrue(initialTeller != pho.tellerAddress());
        assertEq(pho.tellerAddress(), owner);
        vm.stopPrank();
    }

    function testCannotSetTellerAddressZero() public {
        vm.expectRevert("PHO: zero address detected");
        vm.prank(owner);
        pho.setTeller(address(0));
    }

    function testCannotSetTellerNotAllowed() public {
        vm.expectRevert("PHO: Not the owner, controller, or the governance timelock");
        vm.prank(user1);
        pho.setTeller(address(0));
    }

    function testCannotSetTellerSameAddress() public {
        address currentTeller = pho.tellerAddress();
        vm.expectRevert("PHO: same address detected");
        vm.prank(owner);
        pho.setTeller(currentTeller);
    }

    /// setController()

    function testSetController() public {
        vm.startPrank(owner);
        address initialController = pho.controllerAddress();
        vm.expectEmit(false, false, false, true);
        emit ControllerSet(user1);
        pho.setController(user1);

        assertTrue(initialController != pho.controllerAddress());
        assertEq(pho.controllerAddress(), user1);
        vm.stopPrank();
    }

    function testCannotSetControllerAddressZero() public {
        vm.expectRevert("PHO: zero address detected");
        vm.prank(owner);
        pho.setController(address(0));
    }

    function testCannotSetControllerNotAllowed() public {
        vm.expectRevert("PHO: Not the owner, controller, or the governance timelock");
        vm.prank(user1);
        pho.setController(address(0));
    }

    function testCannotSetControllerSameAddress() public {
        address currentController = pho.controllerAddress();
        vm.expectRevert("PHO: same address detected");
        vm.prank(owner);
        pho.setController(currentController);
    }

    /// setTimelock()

    function testSetTimelock() public {
        vm.startPrank(owner);
        address initialTimelock = pho.controllerAddress();
        vm.expectEmit(false, false, false, true);
        emit TimelockSet(user1);
        pho.setTimelock(user1);

        assertTrue(initialTimelock != pho.timelockAddress());
        assertEq(pho.timelockAddress(), user1);
        vm.stopPrank();
    }

    function testCannotSetTimelockAddressZero() public {
        vm.expectRevert("PHO: zero address detected");
        vm.prank(owner);
        pho.setTimelock(address(0));
    }

    function testCannotSetTimelockNotAllowed() public {
        vm.expectRevert("PHO: Not the owner, controller, or the governance timelock");
        vm.prank(user1);
        pho.setTimelock(address(0));
    }

    function testCannotSetTimelockSameAddress() public {
        address currentTimelock = pho.timelockAddress();
        vm.expectRevert("PHO: same address detected");
        vm.prank(owner);
        pho.setTimelock(currentTimelock);
    }
}
