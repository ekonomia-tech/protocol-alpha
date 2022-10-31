// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../BaseSetup.t.sol";

/// @notice point of this test is just to showcase each of the stages for a proposal for PHOGovernance.
contract PHOGovernorBravoDelegatorTest is BaseSetup {
    function setUp() public {
        vm.startPrank(address(kernel));
        pho.mint(owner, ONE_MILLION_D18);
        ton.mint(owner, ONE_MILLION_D18);

        uint256 ownerPHO = pho.balanceOf(owner);
        uint256 ownerTON = ton.balanceOf(owner);
        console.log(
            "owner address: %s, owner pho: %s, current block number: %s",
            owner,
            ownerPHO,
            block.number
        );
        vm.roll(block.number + 1000);
        vm.stopPrank();
    }

    /// NOTE - start the first module: owner proposes addModule(module1), vm.roll(startBlock + 1), owner votes on that proposal so it passes quorumVotes minimum, vm.roll(endBlock + 1), owner `queue()` `addModule(module1)` proposal, vm.warp(proposal.eta + 1), owner `execute()` `addModule(module1)` proposal.
    function testPropose() public {
        _setUpAddedModule();
        // TODO - need to run checks against things here.
    }
}
