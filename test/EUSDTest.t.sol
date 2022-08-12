// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./Setup.t.sol";

// error Unauthorized();

contract EUSDTest is Setup {    
    /// EVENTS
    // TODO - there must be a way to use submodules or something to access the events instead of copying them over here.

    /// IEUSD specific events

    event EUSDBurned(address indexed from, address indexed burnCaller, uint256 amount);
    event EUSDMinted(address indexed mintCaller, address indexed to, uint256 amount);
    event PoolAdded(address pool_address);
    event PoolRemoved(address pool_address);
    event ControllerSet(address controller_address);

    /// ERC20Burnable && ERC20 events

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /// IAccessControl events

    event RoleAdminChanged(
        bytes32 indexed role,
        bytes32 indexed previousAdminRole,
        bytes32 indexed newAdminRole
    );
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /// Ownable events
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    /// setup tests

    function testEUSDConstructor() public {
        assertEq(eusd.creator_address(), owner);
        assertEq(eusd.balanceOf(user1), oneThousand);
        assertEq(eusd.balanceOf(user1), oneThousand);
        assertEq(eusd.name(), "Eusd");
        assertEq(eusd.symbol(), "EUSD");
        assertEq(eusd.decimals(), 18);
    }

    /// allowance() + approve() tests

    // helper
    function setupAllowance(address _user, address _spender, uint256 _amount) public {
        vm.expectEmit(true, true, false, true);
        emit Approval(_user, _spender, _amount);
        vm.prank(_user);
        eusd.approve(_spender, _amount);
    }

    function testApproveAndAllowance() public {
        assertEq(eusd.allowance(user1, user2), 0);
        setupAllowance(user1, user2, fiveHundred / 2);
        assertEq(eusd.allowance(user1, user2), fiveHundred / 2);
    }

    function testIncreaseAllowance() public {
        setupAllowance(user1, user2, fiveHundred / 2);
        uint256 allowanceBefore = eusd.allowance(user1, user2);

        vm.expectEmit(true, true, false, true);
        emit Approval(user1, user2, fiveHundred);
        vm.prank(user1);
        eusd.increaseAllowance(user2, fiveHundred / 2);

        uint256 allowanceAfter = eusd.allowance(user1, user2);
        assertEq(allowanceAfter, allowanceBefore + (fiveHundred / 2));
    }

    function testCannotDecreasePastZero() public {
        setupAllowance(user1, user2, fiveHundred / 2);
        vm.expectRevert("ERC20: decreased allowance below zero");
        vm.prank(user1);
        eusd.decreaseAllowance(user2, fiveHundred);
    }

    function testDecreaseAllowance() public {
        setupAllowance(user1, user2, fiveHundred / 2);
        vm.expectEmit(true, true, false, true);
        emit Approval(user1, user2, 0);
        vm.prank(user1);
        eusd.decreaseAllowance(user2, fiveHundred / 2);
    }

    /// mint() tests
    // TODO - once we implement actual pools, replace owner with an actual pool address

    function testCannotMintNonPool() public {
        vm.expectRevert("Only EUSD pools can call this function");
        vm.prank(user1);
        eusd.pool_mint(user1, fiveHundred);
    }

    function testMint() public {
        uint256 user1Balance = eusd.balanceOf(user1);
        uint256 totalSupply = eusd.totalSupply();
        assertEq(eusd.EUSD_pools(owner), true);

        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), user1, fiveHundred);
        vm.prank(owner);
        eusd.pool_mint(user1, fiveHundred);

        totalSupply = totalSupply + fiveHundred;
        user1Balance = user1Balance + fiveHundred;
        assertEq(eusd.totalSupply(), totalSupply);
        assertEq(eusd.balanceOf(user1), user1Balance);
    }

    /// transferFrom() tests

    function testCannotInsufficientAllowance() public {
        vm.expectEmit(true, true, false, true);
        emit Approval(user1, user2, twoHundred);
        vm.prank(user1);
        eusd.approve(user2, twoHundred);

        vm.expectRevert("ERC20: insufficient allowance");
        vm.prank(user2);
        eusd.transferFrom(user1, user2, twoHundred + fiveHundred);
    }

    function testCannotInsufficientFunds() public {
        uint256 user1Balance = eusd.balanceOf(user1);
        uint256 overTransfer = twoHundred + user1Balance;

        vm.expectEmit(true, true, false, true);
        emit Approval(user1, user2, overTransfer);
        vm.prank(user1);
        eusd.approve(user2, overTransfer);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        vm.prank(user2);
        eusd.transferFrom(user1, user2, overTransfer);
    }

    function testTransferFrom() public {
        uint256 user1Balance = eusd.balanceOf(user1);
        uint256 user2Balance = eusd.balanceOf(user2);
        uint256 ownerBalance = eusd.balanceOf(owner);

        vm.expectEmit(true, true, false, true);
        emit Approval(user1, user2, twoHundred);
        vm.prank(user1);
        eusd.approve(user2, twoHundred);
        assertEq(eusd.allowance(user1, user2), twoHundred);

        vm.expectEmit(true, true, false, true);
        emit Approval(user1, user2, 0);
        emit Transfer(user1, user2, twoHundred);
        vm.prank(user2);
        eusd.transferFrom(user1, user2, twoHundred);

        user1Balance = user1Balance - twoHundred;
        user2Balance = user2Balance + twoHundred;
        assertEq(eusd.balanceOf(user1), user1Balance);
        assertEq(eusd.balanceOf(user2), user2Balance);

        vm.expectEmit(true, true, false, true);
        emit Approval(user2, user1, twoHundred);
        vm.prank(user2);
        eusd.approve(user1, twoHundred);

        assertEq(eusd.allowance(user2, user1), twoHundred);

        vm.expectEmit(true, true, false, true);
        emit Approval(user2, user1, 0);
        emit Transfer(user2, owner, twoHundred);
        vm.prank(user1);
        eusd.transferFrom(user2, owner, twoHundred);

        ownerBalance = ownerBalance + twoHundred;
        user2Balance = user2Balance - twoHundred;

        assertEq(eusd.allowance(user2, user1), 0);
        assertEq(eusd.balanceOf(owner), ownerBalance);
        assertEq(eusd.balanceOf(user2), user2Balance);
        assertEq(eusd.balanceOf(user1), user1Balance);
    }

    /// transfer() tests

    function testCannotTransferExcessFunds() public {
        uint256 user1Balance = eusd.balanceOf(user1);
        uint256 overTransfer = twoHundred + user1Balance;

        vm.expectEmit(true, true, false, true);
        emit Approval(user1, user2, overTransfer);
        vm.prank(user1);
        eusd.approve(user2, overTransfer);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        vm.prank(user2);
        eusd.transfer(user1, overTransfer);
    }

    function testTransfer() public {
        uint256 user1Balance = eusd.balanceOf(user1);
        uint256 user2Balance = eusd.balanceOf(user2);

        vm.expectEmit(true, true, false, true);
        emit Transfer(user2, user1, twoHundred);
        vm.prank(user2);
        eusd.transfer(user1, twoHundred);

        user1Balance = user1Balance + twoHundred;
        user2Balance = user2Balance - twoHundred;

        assertEq(eusd.balanceOf(user1), user1Balance);
        assertEq(eusd.balanceOf(user2), user2Balance);
    }

    /// burnFrom() tests

    function testCannotBurnFromLowAllowance() public {
        vm.expectEmit(true, true, false, true);
        emit Approval(user2, owner, twoHundred);
        vm.prank(user2);
        eusd.approve(owner, twoHundred);

        vm.expectRevert("ERC20: insufficient allowance");
        vm.prank(owner);
        eusd.burnFrom(user2, twoHundred + 1);
    }

    function testCannotBurnFromExcessFunds() public {
        uint256 user1Balance = eusd.balanceOf(user1);
        uint256 overBurn = twoHundred + user1Balance;

        vm.expectEmit(true, true, false, true);
        emit Approval(user1, owner, overBurn);
        vm.prank(user1);
        eusd.approve(owner, overBurn);

        vm.prank(owner);
        vm.expectRevert("ERC20: burn amount exceeds balance");
        eusd.burnFrom(user1, overBurn);
    }

    function testBurnFrom() public {
        uint256 user1Balance = eusd.balanceOf(user1);

        vm.expectEmit(true, true, false, true);
        emit Approval(user1, owner, twoHundred);
        vm.prank(user1);
        eusd.approve(owner, twoHundred);

        assertEq(eusd.allowance(user1, owner), twoHundred);

        vm.expectEmit(true, true, false, true);
        emit Approval(user1, owner, 0);
        emit Transfer(user1, address(0), twoHundred);
        vm.prank(owner);
        eusd.burnFrom(user1, twoHundred);

        user1Balance = user1Balance - twoHundred;

        assertEq(eusd.balanceOf(user1), user1Balance);
    }

    /// burn() tests

    function testCannotBurnExcessFunds() public {
        uint256 overBurn = GENESIS_SUPPLY + 1;

        vm.expectRevert("ERC20: burn amount exceeds balance");
        vm.prank(owner);
        eusd.burn(overBurn);
    }

    function testBurn() public {
        uint256 ownerBalance = eusd.balanceOf(owner);
        uint256 totalSupply = eusd.totalSupply();

        vm.expectEmit(true, true, false, true);
        emit Transfer(owner, address(0), twoHundred);
        vm.prank(owner);
        eusd.burn(twoHundred);

        ownerBalance = ownerBalance - twoHundred;
        assertEq(eusd.totalSupply(), totalSupply - twoHundred);
        assertEq(eusd.balanceOf(owner), ownerBalance);
    }

    /// pool_burn_from() tests

    function testCannotPoolBurn() public {
        vm.expectRevert("Only EUSD pools can call this function");
        vm.prank(user1);
        eusd.pool_burn_from(user1, oneHundred);
    }

    // NOTE - this will likely need adjustment once we write EUSDPool contracts
    function testPoolBurn() public {
        vm.prank(user1);
        eusd.approve(owner, oneHundred);
        vm.startPrank(owner);

        vm.expectEmit(true, true, false, true);
        emit EUSDBurned(user1, owner, oneHundred);
        eusd.pool_burn_from(user1, oneHundred);  
        vm.stopPrank();      
    }

    function testCannotPoolBurnExcessAllowance() public {
        vm.prank(user1);
        eusd.approve(owner, oneHundred);
        uint256 overburn = oneHundred + 1;
        vm.startPrank(owner);
        vm.expectRevert("ERC20: insufficient allowance");
        eusd.pool_burn_from(user1, overburn);  
        vm.stopPrank();
    }
    
    function testCannotPoolBurnExcessBalance() public {
        uint256 userBalance = eusd.balanceOf(user1);
        uint256 excessBurn = userBalance + 1;
        vm.prank(user1);
        eusd.approve(owner, excessBurn);
        vm.startPrank(owner);
        vm.expectRevert("ERC20: burn amount exceeds balance");
        eusd.pool_burn_from(user1, excessBurn);  
        vm.stopPrank();
    }

    /// pool_mint() tests
 
    function testCannotPoolMint() public {
        vm.startPrank(user1);
        vm.expectRevert("Only EUSD pools can call this function");
        eusd.pool_mint(user1, oneHundred);  
        vm.stopPrank();    
    }    
    
    // NOTE - this will likely need adjustment once we write EUSDPool contracts
    function testPoolMint() public {
        vm.startPrank(owner);
        
        vm.expectEmit(true, true, false, true);
        emit EUSDMinted(owner, user1, oneHundred);
        eusd.pool_mint(user1, oneHundred);  
        vm.stopPrank();    
    }

    /// addPool() tests

    function testAddPoolOwner() public {
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit PoolAdded(dummyAddress);
        eusd.addPool(dummyAddress);
        vm.stopPrank();
    }

    function testAddPoolGovernance() public {
        vm.startPrank(timelock_address);
        vm.expectEmit(true, false, false, true);
        emit PoolAdded(dummyAddress);
        eusd.addPool(dummyAddress);
        vm.stopPrank();
    }

    // NOTE - do we want to have the controller set in the constructor or have it added after the fact of EUSD deployment?
    function testAddPoolController() public {
        vm.startPrank(controller);
        vm.expectEmit(true, false, false, true);
        emit PoolAdded(dummyAddress);
        eusd.addPool(dummyAddress);
        vm.stopPrank();
    }

    function testCannotAddPool() public {
        vm.startPrank(user1);
        vm.expectRevert("Not the owner, controller, or the governance timelock");
        eusd.addPool(dummyAddress);
        vm.stopPrank();
    }

    function testCannotAddPoolZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert("Zero address detected");
        eusd.addPool(address(0));
        vm.stopPrank();
    }

    function testCannotAddPoolDuplicate() public {
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit PoolAdded(dummyAddress);
        eusd.addPool(dummyAddress);

        vm.expectRevert("Address already exists");
        eusd.addPool(dummyAddress);
        vm.stopPrank();
    }

    function testAddPreExistingPool() public {
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit PoolAdded(dummyAddress);
        eusd.addPool(dummyAddress);

        vm.expectEmit(true, false, false, true);
        emit PoolRemoved(dummyAddress);
        eusd.removePool(dummyAddress);

        vm.expectEmit(true, false, false, true);
        emit PoolAdded(dummyAddress);
        eusd.addPool(dummyAddress);
        vm.stopPrank();
    }

    /// removePool() tests

    function testRemovePool() public {
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit PoolAdded(dummyAddress);
        eusd.addPool(dummyAddress);
        address arrayOne = eusd.EUSD_pools_array(1);
        assertEq(arrayOne, dummyAddress);

        vm.expectEmit(true, false, false, true);
        emit PoolRemoved(dummyAddress);
        eusd.removePool(dummyAddress);
        address arrayOneNew = eusd.EUSD_pools_array(1);
        assertEq(arrayOneNew, address(0));
        vm.stopPrank();
    }

    function testCannotRemovePool() public {
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit PoolAdded(dummyAddress);
        eusd.addPool(dummyAddress);

        vm.expectEmit(true, false, false, true);
        emit PoolRemoved(dummyAddress);
        eusd.removePool(dummyAddress);
        vm.stopPrank();
        
        vm.expectRevert("Not the owner, controller, or the governance timelock");
        vm.prank(user1);
        eusd.removePool(dummyAddress);
    }

    function testCannotRemovePoolZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert("Zero address detected");
        eusd.removePool(address(0));
        vm.stopPrank();
    }
    
    // NOTE - Considering doing the below test too but seems overkill:
    // add pool, remove pool, remove pool again and expect revert
    function testCannotRemoveUnaddedPool() public {
        vm.startPrank(owner);
        vm.expectRevert("Address nonexistant");
        eusd.removePool(dummyAddress);
        vm.stopPrank();
    }

    /// setController() tests

    function testCannotUpdateZero() public {
        vm.expectRevert("Zero address detected");
        vm.prank(owner);
        eusd.setController(address(0));
    }

    function testSetController() public {
        vm.startPrank(owner);
        address initialController = eusd.controller_address();
        vm.expectEmit(false, false, false, true);
        emit ControllerSet(user1);
        eusd.setController(user1);

        assertEq(initialController != eusd.controller_address(), true); // workaround for assertNotEq() for now until I try importing this submodule I picked up from the foundry TG: https://github.com/paulrberg/prb-test
        assertEq(eusd.controller_address(), user1);
        vm.stopPrank();
    }
}