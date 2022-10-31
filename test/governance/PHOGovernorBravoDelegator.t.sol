// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../BaseSetup.t.sol";

contract PHOGovernorBravoDelegatorTest is BaseSetup {

    function setUp() public {
        vm.startPrank(address(kernel));
        pho.mint(owner, ONE_MILLION_D18);
        ton.mint(owner, ONE_MILLION_D18);
        vm.stopPrank();
    }

    /// TODO - start the first module: owner proposes addModule(module1), vm.roll(startBlock + 1), owner votes on that proposal so it passes quorumVotes minimum, vm.roll(endBlock + 1), owner `queue()` `addModule(module1)` proposal, vm.warp(proposal.eta + 1), owner `execute()` `addModule(module1)` proposal.

    function testPropose() public {

        vm.startPrank(owner);
        // Propose - note require for proposal threshold is commented out

        address[] memory targets = new address[](1);
        targets[0] = owner;

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        string[] memory signatures = new string[](1);
        signatures[0] = "addModule(address _newModule)";

        bytes[] memory callDatas = new bytes[](1);
        callDatas[0] = abi.encode("address _newModule", module1);

        string memory description = "Add new module";

        _propose(PHOGovernance, targets, values, signatures, callDatas, description);

        // (bool proposeSuccess, bytes memory proposeResult) = address(
        //     phoGovernanceDelegator
        // ).call(
        //         abi.encodeWithSignature(
        //             "propose(address[],uint256[],string[],bytes[],string)",
        //             targets,
        //             values,
        //             signatures,
        //             callDatas,
        //             description
        //         )
        //     );

        console.log("THIS IS proposeSuccess: ", proposeSuccess);

        (
            bool newProposalCountSuccess,
            bytes memory newProposalCountResult
        ) = address(phoGovernanceDelegator).call(
                abi.encodeWithSignature("proposalCount()")
            );

        uint256 newProposalCount = abi.decode(
            newProposalCountResult,
            (uint256)
        );
        console.log("THIS IS newProposalCount : ", newProposalCount);

        vm.stopPrank();
    }

    function testVote() public {

    }



    
}
