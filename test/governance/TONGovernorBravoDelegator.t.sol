// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../BaseSetup.t.sol";

contract TONGovernorBravoDelegatorTest is BaseSetup {
    function setUp() public {
        vm.startPrank(address(kernel));
        pho.mint(owner, ONE_MILLION_D18);
        ton.mint(owner, ONE_MILLION_D18);

        uint256 ownerPHO = pho.balanceOf(owner);
        uint256 ownerTON = ton.balanceOf(owner);

        vm.roll(block.number + 1000);
        vm.stopPrank();
    }

    /// NOTE - start the first module: owner proposes addModule(module1), vm.roll(startBlock + 1), owner votes on that proposal so it passes quorumVotes minimum, vm.roll(endBlock + 1), owner `queue()` `addModule(module1)` proposal, vm.warp(proposal.eta + 1), owner `execute()` `addModule(module1)` proposal.
    function testSetPHOCeiling() public {
        _setUpAddedModule();

        vm.startPrank(owner);

        address[] memory targets = new address[](1);
        targets[0] = address(moduleManager);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        string[] memory signatures = new string[](1);
        signatures[0] = "setPHOCeilingForModule(address _module, uint256 _newPHOCeiling)";
        bytes[] memory callDatas = new bytes[](1);
        callDatas[0] =
            abi.encode("address _module, uint256 _newPHOCeiling", module1, ONE_MILLION_D18);
        string memory description = "Set PHOCeiling for new module";

        _propose(TONGovernance, targets, values, signatures, callDatas, description);

        uint256 proposalStartBlock = block.number;

        // check that proposal is set up well and get the proposalID.
        (bool newInitialProposalIdSuccess, bytes memory newInitialProposalIdResult) =
            TONGovernance.call(abi.encodeWithSignature("initialProposalId()"));

        uint256 newInitialProposalId = abi.decode(newInitialProposalIdResult, (uint256));

        // next, cast votes to get proposal to succeed
        _castVote(TONGovernance, newInitialProposalId, 1);

        // next, roll forward duration of proposal && queue
        vm.roll(proposalStartBlock + VOTING_PERIOD + 1);
        _queue(TONGovernance, newInitialProposalId);
        _execute(TONGovernance, newInitialProposalId);

        vm.stopPrank();
    }
}
