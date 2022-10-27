// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../BaseSetup.t.sol";

contract PHOGovernorBravoDelegateTest is BaseSetup {
    /// Errors
    
    // Set up delegate with blank address
    // setup delegator with proper addresses
    // now pho and ton tokens are associated to governorBravo
    // now mint pho and ton tokens for other tests
    // carry out proposal creation
    // carry out voting for it
    // carry out queuing it
    // carry out executing it
    // carry out checking that things were executed
    function setUp() public {
        vm.startPrank(owner);
        
        // mint some PHO && send it to owner && user1 && user2
        // propose a dummy porposal from user1
        // run tests on it
        // TODO - determine what extent of tests need to be ran.
        // just test that a proposal can be pushed, passed and queued, and executed.
        // We only want to allow governance of adding a module and increasing threshold.
        

        vm.stopPrank();
    }

    // TODO - FIRST TEST: I guess run a blank test to start. Just see that governance is setup and all other tests aren't broken.
    function testSetUp() public {

    }

}