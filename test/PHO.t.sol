// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseSetup.t.sol";

// error Unauthorized();

contract PHOTest is BaseSetup {
    /// EVENTS
    // TODO - there must be a way to use submodules or something to access the events instead of copying them over here.

    /// IPHO specific events

    event PHOBurned(address indexed from, address indexed burnCaller, uint256 amount);
    event PHOMinted(address indexed mintCaller, address indexed to, uint256 amount);
    event PoolAdded(address pool_address);
    event PoolRemoved(address pool_address);
    event ControllerSet(address controller_address);

    /// ERC20Burnable && ERC20 events

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /// Ownable events
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// setup tests

    function testPHOConstructor() public {
        assertEq(pho.creator_address(), owner);
        assertEq(pho.balanceOf(user1), tenThousand_d18);
        assertEq(pho.name(), "Pho");
        assertEq(pho.symbol(), "PHO");
        assertEq(pho.decimals(), 18);
    }

    /// allowance() + approve() tests

    // helper
    function setupAllowance(address _user, address _spender, uint256 _amount) public {
        vm.expectEmit(true, true, false, true);
        emit Approval(_user, _spender, _amount);
        vm.prank(_user);
        pho.approve(_spender, _amount);
    }

    function testApproveAndAllowance() public {
        assertEq(pho.allowance(user1, user2), 0);
        setupAllowance(user1, user2, fiveHundred_d18 / 2);
        assertEq(pho.allowance(user1, user2), fiveHundred_d18 / 2);
    }

    function testIncreaseAllowance() public {
        setupAllowance(user1, user2, fiveHundred_d18 / 2);
        uint256 allowanceBefore = pho.allowance(user1, user2);

        vm.expectEmit(true, true, false, true);
        emit Approval(user1, user2, fiveHundred_d18);
        vm.prank(user1);
        pho.increaseAllowance(user2, fiveHundred_d18 / 2);

        uint256 allowanceAfter = pho.allowance(user1, user2);
        assertEq(allowanceAfter, allowanceBefore + (fiveHundred_d18 / 2));
    }

    function testCannotDecreasePastZero() public {
        setupAllowance(user1, user2, fiveHundred_d18 / 2);
        vm.expectRevert("ERC20: decreased allowance below zero");
        vm.prank(user1);
        pho.decreaseAllowance(user2, fiveHundred_d18);
    }

    function testDecreaseAllowance() public {
        setupAllowance(user1, user2, fiveHundred_d18 / 2);
        vm.expectEmit(true, true, false, true);
        emit Approval(user1, user2, 0);
        vm.prank(user1);
        pho.decreaseAllowance(user2, fiveHundred_d18 / 2);
    }

    /// mint() tests

    function testCannotMintNonPool() public {
        vm.expectRevert("Only PHO pools can call this function");
        vm.prank(user1);
        pho.pool_mint(user1, fiveHundred_d18);
    }

    function testMint() public {
        uint256 user1Balance = pho.balanceOf(user1);
        uint256 totalSupply = pho.totalSupply();
        assertEq(pho.PHO_pools(address(pool_usdc)), true);

        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), user1, fiveHundred_d18);
        vm.prank(address(pool_usdc));
        pho.pool_mint(user1, fiveHundred_d18);

        totalSupply = totalSupply + fiveHundred_d18;
        user1Balance = user1Balance + fiveHundred_d18;
        assertEq(pho.totalSupply(), totalSupply);
        assertEq(pho.balanceOf(user1), user1Balance);
    }

    /// transferFrom() tests

    function testCannotInsufficientAllowance() public {
        vm.expectEmit(true, true, false, true);
        emit Approval(user1, user2, twoHundred_d18);
        vm.prank(user1);
        pho.approve(user2, twoHundred_d18);

        vm.expectRevert("ERC20: insufficient allowance");
        vm.prank(user2);
        pho.transferFrom(user1, user2, twoHundred_d18 + fiveHundred_d18);
    }

    function testCannotInsufficientFunds() public {
        uint256 user1Balance = pho.balanceOf(user1);
        uint256 overTransfer = twoHundred_d18 + user1Balance;

        vm.expectEmit(true, true, false, true);
        emit Approval(user1, user2, overTransfer);
        vm.prank(user1);
        pho.approve(user2, overTransfer);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        vm.prank(user2);
        pho.transferFrom(user1, user2, overTransfer);
    }

    function testTransferFrom() public {
        uint256 user1Balance = pho.balanceOf(user1);
        uint256 user2Balance = pho.balanceOf(user2);
        uint256 ownerBalance = pho.balanceOf(owner);

        vm.expectEmit(true, true, false, true);
        emit Approval(user1, user2, twoHundred_d18);
        vm.prank(user1);
        pho.approve(user2, twoHundred_d18);
        assertEq(pho.allowance(user1, user2), twoHundred_d18);

        vm.expectEmit(true, true, false, true);
        emit Approval(user1, user2, 0);
        emit Transfer(user1, user2, twoHundred_d18);
        vm.prank(user2);
        pho.transferFrom(user1, user2, twoHundred_d18);

        user1Balance = user1Balance - twoHundred_d18;
        user2Balance = user2Balance + twoHundred_d18;
        assertEq(pho.balanceOf(user1), user1Balance);
        assertEq(pho.balanceOf(user2), user2Balance);

        vm.expectEmit(true, true, false, true);
        emit Approval(user2, user1, twoHundred_d18);
        vm.prank(user2);
        pho.approve(user1, twoHundred_d18);

        assertEq(pho.allowance(user2, user1), twoHundred_d18);

        vm.expectEmit(true, true, false, true);
        emit Approval(user2, user1, 0);
        emit Transfer(user2, owner, twoHundred_d18);
        vm.prank(user1);
        pho.transferFrom(user2, owner, twoHundred_d18);

        ownerBalance = ownerBalance + twoHundred_d18;
        user2Balance = user2Balance - twoHundred_d18;

        assertEq(pho.allowance(user2, user1), 0);
        assertEq(pho.balanceOf(owner), ownerBalance);
        assertEq(pho.balanceOf(user2), user2Balance);
        assertEq(pho.balanceOf(user1), user1Balance);
    }

    /// transfer() tests

    function testCannotTransferExcessFunds() public {
        uint256 user1Balance = pho.balanceOf(user1);
        uint256 overTransfer = twoHundred_d18 + user1Balance;

        vm.expectEmit(true, true, false, true);
        emit Approval(user1, user2, overTransfer);
        vm.prank(user1);
        pho.approve(user2, overTransfer);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        vm.prank(user2);
        pho.transfer(user1, overTransfer);
    }

    function testTransfer() public {
        uint256 user1Balance = pho.balanceOf(user1);
        uint256 user2Balance = pho.balanceOf(user2);

        vm.expectEmit(true, true, false, true);
        emit Transfer(user2, user1, twoHundred_d18);
        vm.prank(user2);
        pho.transfer(user1, twoHundred_d18);

        user1Balance = user1Balance + twoHundred_d18;
        user2Balance = user2Balance - twoHundred_d18;

        assertEq(pho.balanceOf(user1), user1Balance);
        assertEq(pho.balanceOf(user2), user2Balance);
    }

    /// burnFrom() tests

    function testCannotBurnFromLowAllowance() public {
        vm.expectEmit(true, true, false, true);
        emit Approval(user2, owner, twoHundred_d18);
        vm.prank(user2);
        pho.approve(owner, twoHundred_d18);

        vm.expectRevert("ERC20: insufficient allowance");
        vm.prank(owner);
        pho.burnFrom(user2, twoHundred_d18 + 1);
    }

    function testCannotBurnFromExcessFunds() public {
        uint256 user1Balance = pho.balanceOf(user1);
        uint256 overBurn = twoHundred_d18 + user1Balance;

        vm.expectEmit(true, true, false, true);
        emit Approval(user1, owner, overBurn);
        vm.prank(user1);
        pho.approve(owner, overBurn);

        vm.prank(owner);
        vm.expectRevert("ERC20: burn amount exceeds balance");
        pho.burnFrom(user1, overBurn);
    }

    function testBurnFrom() public {
        uint256 user1Balance = pho.balanceOf(user1);

        vm.expectEmit(true, true, false, true);
        emit Approval(user1, owner, twoHundred_d18);
        vm.prank(user1);
        pho.approve(owner, twoHundred_d18);

        assertEq(pho.allowance(user1, owner), twoHundred_d18);

        vm.expectEmit(true, true, false, true);
        emit Approval(user1, owner, 0);
        emit Transfer(user1, address(0), twoHundred_d18);
        vm.prank(owner);
        pho.burnFrom(user1, twoHundred_d18);
        user1Balance = user1Balance - twoHundred_d18;

        assertEq(pho.balanceOf(user1), user1Balance);
    }

    /// burn() tests

    function testCannotBurnExcessFunds() public {
        uint256 overBurn = GENESIS_SUPPLY_d18 + 1;

        vm.expectRevert("ERC20: burn amount exceeds balance");
        vm.prank(owner);
        pho.burn(overBurn);
    }

    function testBurn() public {
        uint256 ownerBalance = pho.balanceOf(owner);
        uint256 totalSupply = pho.totalSupply();

        vm.expectEmit(true, true, false, true);
        emit Transfer(owner, address(0), twoHundred_d18);
        vm.prank(owner);
        pho.burn(twoHundred_d18);

        ownerBalance = ownerBalance - twoHundred_d18;
        assertEq(pho.totalSupply(), totalSupply - twoHundred_d18);
        assertEq(pho.balanceOf(owner), ownerBalance);
    }

    /// pool_burn_from() tests

    function testCannotPoolBurn() public {
        vm.expectRevert("Only PHO pools can call this function");
        vm.prank(user1);
        pho.pool_burn_from(user1, oneHundred_d18);
    }

    function testPoolBurn() public {
        vm.prank(user1);
        pho.approve(address(pool_usdc), oneHundred_d18);
        vm.startPrank(address(pool_usdc));

        vm.expectEmit(true, true, false, true);
        emit PHOBurned(user1, address(pool_usdc), oneHundred_d18);
        pho.pool_burn_from(user1, oneHundred_d18);
        vm.stopPrank();
    }

    function testCannotPoolBurnExcessAllowance() public {
        vm.prank(user1);
        pho.approve(address(pool_usdc), oneHundred_d18);
        uint256 overburn = oneHundred_d18 + 1;
        vm.startPrank(address(pool_usdc));
        vm.expectRevert("ERC20: insufficient allowance");
        pho.pool_burn_from(user1, overburn);
        vm.stopPrank();
    }

    function testCannotPoolBurnExcessBalance() public {
        uint256 userBalance = pho.balanceOf(user1);
        uint256 excessBurn = userBalance + 1;
        vm.prank(user1);
        pho.approve(address(pool_usdc), excessBurn);
        vm.startPrank(address(pool_usdc));
        vm.expectRevert("ERC20: burn amount exceeds balance");
        pho.pool_burn_from(user1, excessBurn);
        vm.stopPrank();
    }

    /// pool_mint() tests

    function testCannotPoolMint() public {
        vm.startPrank(user1);
        vm.expectRevert("Only PHO pools can call this function");
        pho.pool_mint(user1, oneHundred_d18);
        vm.stopPrank();
    }

    function testPoolMint() public {
        vm.startPrank(address(pool_usdc));
        vm.expectEmit(true, true, false, true);
        emit PHOMinted(address(pool_usdc), user1, oneHundred_d18);
        pho.pool_mint(user1, oneHundred_d18);
        vm.stopPrank();
    }

    /// addPool() tests

    function testAddPoolOwner() public {
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit PoolAdded(dummyAddress);
        pho.addPool(dummyAddress);
        vm.stopPrank();
    }

    function testAddPoolGovernance() public {
        vm.startPrank(timelock_address);
        vm.expectEmit(true, false, false, true);
        emit PoolAdded(dummyAddress);
        pho.addPool(dummyAddress);
        vm.stopPrank();
    }

    // NOTE - do we want to have the controller set in the constructor or have it added after the fact of PHO deployment?
    function testAddPoolController() public {
        vm.startPrank(controller);
        vm.expectEmit(true, false, false, true);
        emit PoolAdded(dummyAddress);
        pho.addPool(dummyAddress);
        vm.stopPrank();
    }

    function testCannotAddPool() public {
        vm.startPrank(user1);
        vm.expectRevert("Not the owner, controller, or the governance timelock");
        pho.addPool(dummyAddress);
        vm.stopPrank();
    }

    function testCannotAddPoolZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert("Zero address detected");
        pho.addPool(address(0));
        vm.stopPrank();
    }

    function testCannotAddPoolDuplicate() public {
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit PoolAdded(dummyAddress);
        pho.addPool(dummyAddress);

        vm.expectRevert("Address already exists");
        pho.addPool(dummyAddress);
        vm.stopPrank();
    }

    function testAddPreExistingPool() public {
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit PoolAdded(dummyAddress);
        pho.addPool(dummyAddress);

        vm.expectEmit(true, false, false, true);
        emit PoolRemoved(dummyAddress);
        pho.removePool(dummyAddress);

        vm.expectEmit(true, false, false, true);
        emit PoolAdded(dummyAddress);
        pho.addPool(dummyAddress);
        vm.stopPrank();
    }

    /// removePool() tests

    /// NOTE - test will fail if pool contract not implemented due to array element within question here (pool setup has initialusdc pool setup)
    function testRemovePool() public {
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit PoolAdded(dummyAddress);
        pho.addPool(dummyAddress);
        address arrayThree = pho.PHO_pools_array(2);
        assertEq(arrayThree, dummyAddress);

        vm.expectEmit(true, false, false, true);
        emit PoolRemoved(dummyAddress);
        pho.removePool(dummyAddress);
        address arrayThreeNew = pho.PHO_pools_array(2);
        assertEq(arrayThreeNew, address(0));
        vm.stopPrank();
    }

    function testCannotRemovePool() public {
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit PoolAdded(dummyAddress);
        pho.addPool(dummyAddress);

        vm.expectEmit(true, false, false, true);
        emit PoolRemoved(dummyAddress);
        pho.removePool(dummyAddress);
        vm.stopPrank();

        vm.expectRevert("Not the owner, controller, or the governance timelock");
        vm.prank(user1);
        pho.removePool(dummyAddress);
    }

    function testCannotRemovePoolZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert("Zero address detected");
        pho.removePool(address(0));
        vm.stopPrank();
    }

    // NOTE - Considering doing the below test too but seems overkill:
    // add pool, remove pool, remove pool again and expect revert
    function testCannotRemoveUnaddedPool() public {
        vm.startPrank(owner);
        vm.expectRevert("Address nonexistant");
        pho.removePool(dummyAddress);
        vm.stopPrank();
    }

    /// setController() tests

    function testCannotUpdateZero() public {
        vm.expectRevert("Zero address detected");
        vm.prank(owner);
        pho.setController(address(0));
    }

    function testSetController() public {
        vm.startPrank(owner);
        address initialController = pho.controller_address();
        vm.expectEmit(false, false, false, true);
        emit ControllerSet(user1);
        pho.setController(user1);

        assertEq(initialController != pho.controller_address(), true);
        assertEq(pho.controller_address(), user1);
        vm.stopPrank();
    }
}
