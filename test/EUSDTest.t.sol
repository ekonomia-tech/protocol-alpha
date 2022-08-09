// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./Setup.t.sol";

error Unauthorized();

contract EUSDTest is Setup {
    /// vars
    uint256 public constant GENESIS_SUPPLY = 2000000e18;
    
    /// EVENTS

    // TODO - there must be a way to use submodules or something to access the events instead of copying them over here.

    /// IEUSD specific events

    /// Track EUSD burned 
    event EUSDBurned(address indexed from, address indexed to, uint256 amount);
    /// Track EUSD minted
    event EUSDMinted(address indexed from, address indexed to, uint256 amount);
    /// Track pools added
    event PoolAdded(address pool_address);
    /// Track pools removed
    event PoolRemoved(address pool_address);
    /// Track governing controller contract
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


    /// Helper functions

    function stringToBytes32(string memory source) public pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            result := mload(add(source, 32))
        }
    }
    
    /// setup tests

    // TODO - complete once we have addressesRegistry
    function testStablecoinAddress() public {
        // bytes32 EUSD = stringToBytes32("EUSD");
        // assertEq(address(eusd), addressesRegistry.getAddress(EUSD));
    }

    function testCreatorAddress() public {
        assertEq(eusd.creator_address(), owner);
    }

    /// Base functionality tests

    function testBalanceOf() public {
        assertEq(eusd.balanceOf(user1), oneThousand);
    }

    function testTotalSupply() public {
        assertEq(eusd.totalSupply(), GENESIS_SUPPLY);
    }

    function testName() public {
        assertEq(eusd.name(), "Eusd");
    }

    function testSymbol() public {
        assertEq(eusd.symbol(), "EUSD");
    }

    function testDecimals() public {
        assertEq(eusd.decimals(), 18);
    }

    /// allowance() + approve() tests

    // helper
    function setupAllowance(address _user, address _spender) public {
        vm.expectEmit(true, true, false, true);
        emit Approval(_user, _spender, fiveHundred / 2);
        vm.prank(_user);
        eusd.approve(_spender, fiveHundred / 2);
    }

    function testApproveAndAllowance() public {
        assertEq(eusd.allowance(user1, user2), 0);

        setupAllowance(user1, user2);

        assertEq(eusd.allowance(user1, user2), fiveHundred / 2);
    }

    function testIncreaseAllowance() public {
        setupAllowance(user1, user2);
        uint256 allowanceBefore = eusd.allowance(user1, user2);

        vm.expectEmit(true, true, false, true);
        emit Approval(user1, user2, fiveHundred);
        vm.prank(user1);
        eusd.increaseAllowance(user2, fiveHundred / 2);

        uint256 allowanceAfter = eusd.allowance(user1, user2);
        assertEq(allowanceAfter, allowanceBefore + (fiveHundred / 2));
    }

    function testCannotDecreasePastZero() public {
        setupAllowance(user1, user2);

        vm.expectRevert("ERC20: decreased allowance below zero");
        vm.prank(user1);
        eusd.decreaseAllowance(user2, fiveHundred);
    }

    function testDecreaseAllowance() public {
        setupAllowance(user1, user2);

        vm.expectEmit(true, true, false, true);
        emit Approval(user1, user2, 0);
        vm.prank(user1);
        eusd.decreaseAllowance(user2, fiveHundred / 2);
    }

    /// mint() tests
    // TODO - sort out who can mint, I don't think we want a generic mint functionality, aside from pools, so we can make this pool minting. Test by making a dummyAddress the pool, then have it mint accordingly! 1. Test adding a pool role, 2. test minting pool role

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
        emit Approval(user2, user1, twoHundred);
        vm.prank(user2);
        eusd.approve(user1, twoHundred);

        vm.expectRevert("ERC20: insufficient allowance");
        vm.prank(user1);
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
    // TODO - need to sort out if we are going to restrict the generic `burn()` and `burnFrom()` functions from ERC20Burnable.sol. Likely are, and if so, what address gets ownership over it? 

    function burnHelper() public {
        vm.prank(owner);
        eusd.pool_mint(owner, twoHundred * 2);
    }

    function testCannotBurnNotTeller() public {
        burnHelper();
        vm.expectRevert("UNAUTHORIZED TO PERFORM");
        vm.prank(user1);
        eusd.burn(twoHundred + 1);
    }

    function testCannotBurnExcessFunds() public {
        burnHelper();
        uint256 overBurn = twoHundred * 4;

        vm.expectRevert("ERC20: burn amount exceeds balance");
        eusd.burn(overBurn);
    }

    function testBurn() public {
        burnHelper();
        uint256 ownerBalance = eusd.balanceOf(owner);
        uint256 totalSupply = eusd.totalSupply();

        vm.expectEmit(true, true, false, true);
        emit Transfer(owner, address(0), twoHundred);
        eusd.burn(twoHundred);

        ownerBalance = ownerBalance - twoHundred;

        assertEq(eusd.totalSupply(), totalSupply - twoHundred);
        assertEq(eusd.balanceOf(owner), ownerBalance);
    }


    // // TODO
    // /// pool_burn_from() tests

    // // TODO
    // /// pool_mint() tests

    // // TODO
    // /// addPool() tests

    // // TODO
    // /// removePool() tests

    // // TODO
    // /// setController() tests

    // function testCannotUpdateZero() public {
    //     vm.expectRevert("CANNOT BE ZERO ADDRESS");
    //     stablecoin.updateController(address(0));
    // }

    // function testUpdateController() public {
    //     bytes32 GRANTER = stablecoin.GRANTER();
    //     address controller = stablecoin.controller();
    //     vm.expectEmit(false, false, false, true);
    //     emit ControllerSet(user1);
    //     stablecoin.updateController(user1);

    //     assertEq(controller != stablecoin.controller(), true); // workaround for assertNotEq() for now until I try importing this submodule I picked up from the foundry TG: https://github.com/paulrberg/prb-test
    //     assertEq(stablecoin.controller(), user1);
    //     assertEq(stablecoin.hasRole(GRANTER, user1), true);
    // }

    

    //     /// AccessRoles tests (TODO - check if we need these or not based on design)

    // // NOTE this test may not be needed since it's really just testing accessControl
    // function testWETHRoleTellers() public {
    //     bytes32 TELLER = stablecoin.TELLER();
    //     assertEq(stablecoin.hasRole(TELLER, address(wethPool)), true);
    // }

    // function testGranter() public {
    //     bytes32 GRANTER = stablecoin.GRANTER();
    //     address controller = stablecoin.controller();

    //     assertEq(stablecoin.hasRole(GRANTER, address(cdpManager)), true);
    //     assertEq(stablecoin.hasRole(GRANTER, controller), true);
    // }

    // /// registerTeller() tests

    // function testCannotRegisterZero() public {
    //     vm.expectRevert("CANNOT BE ZERO ADDRESS");
    //     stablecoin.registerTeller(address(0));
    // }

    // function testCannotRegisterDuplicate() public {
    //     vm.expectRevert("ADDRESS ALREADY EXISTS");
    //     stablecoin.registerTeller(address(wethPool));
    // }

    // function testRegisterTeller() public {
    //     bytes32 TELLER = stablecoin.TELLER();
    //     address fakePool = user1;

    //     vm.expectEmit(false, false, false, true);
    //     emit TellerRegistered(fakePool);
    //     emit RoleGranted(TELLER, fakePool, owner);
    //     stablecoin.registerTeller(fakePool);

    //     assertEq(stablecoin.hasRole(TELLER, fakePool), true);
    //     assertEq(stablecoin.tellers(fakePool), true);
    // }

    // /// unregisterTeller() tests

    // function testCannotUnregisterZero() public {
    //     vm.expectRevert("CANNOT BE ZERO ADDRESS");
    //     stablecoin.unregisterTeller(address(0));
    // }

    // function testCannotUnregisterNotRegistered() public {
    //     vm.expectRevert("ADDRESS DOESNT EXISTS");
    //     stablecoin.unregisterTeller(user1);
    // }

    // function testUnregisterTeller() public {
    //     bytes32 TELLER = stablecoin.TELLER();
    //     address fakePool = user1;

    //     vm.expectEmit(false, false, false, true);
    //     emit TellerRegistered(fakePool);
    //     stablecoin.registerTeller(fakePool);

    //     assertEq(stablecoin.hasRole(TELLER, fakePool), true);
    //     assertEq(stablecoin.tellers(fakePool), true);

    //     vm.expectEmit(false, false, false, true);
    //     emit TellerUnregistered(fakePool);
    //     emit RoleRevoked(TELLER, fakePool, owner);
    //     stablecoin.unregisterTeller(fakePool);

    //     assertEq(stablecoin.hasRole(TELLER, fakePool), false);
    //     assertEq(stablecoin.tellers(fakePool), false);
    // }
}