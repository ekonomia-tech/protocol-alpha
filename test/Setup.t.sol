// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { EUSD } from "../src/contracts/EUSD.sol";
// import { AddressesRegistry } from "../../contracts/AddressesRegistry.sol";

contract Setup is Test {
    
    EUSD public eusd;
   
    address public owner = address(0x1337);
    address public timelock_address = address(42);
    address public controller = address(56);
    address public user1 = address(1);
    address public user2 = address(2);
    address public user3 = address(3);
    address public dummyAddress = address(23);

    uint256 public fiveHundred = 500 * 10**8;
    uint256 public oneHundred = 100 * 10**8;
    uint256 public fifty = 50 * 10**8;
    uint256 public twentyFive = 25 * 10**8;
    uint256 public twoHundred = 200 * 10**8;
    uint256 public oneThousand = 1000 * 10**8;

    uint256 public constant GENESIS_SUPPLY = 2000000e18;


    function setUp() public {
        vm.startPrank(owner);
        eusd = new EUSD("Eusd", "EUSD", owner, timelock_address);
        
        // TODO - make an addressesRegistry
        // addressesRegistry = new AddressesRegistry();
        // addressesRegistry.setAddress("EUSD", address(eusd)); 
        // eusd.registerTeller(address());

        eusd.transfer(user1, oneThousand);
        eusd.transfer(user2, oneThousand);
        eusd.transfer(user3, oneThousand);
        eusd.addPool(owner);
        eusd.setController(controller);

        vm.stopPrank();
    }


}