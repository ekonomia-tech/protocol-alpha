// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "../BaseSetup.t.sol";
import "@protocol/interfaces/IModuleManager.sol";

contract GovernanceTest is BaseSetup {
    address public TON_timelock_address = address(103);

    function setUp() public {
        vm.prank(owner);
        pho.delegate(owner);

        vm.prank(user1);
        pho.delegate(user1);

        vm.startPrank(address(kernel));
        pho.mint(owner, TEN_THOUSAND_D18);
        pho.mint(user1, TEN_THOUSAND_D18);

        vm.stopPrank();
        vm.roll(block.number + 100);
    }

    function testSetUpProposal() public returns (uint256) {
        vm.startPrank(owner);

        address[] memory targets = new address[](1);
        targets[0] = address(moduleManager);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        string[] memory signatures = new string[](1);
        signatures[0] = "addModule(address)";
        bytes[] memory callDatas = new bytes[](1);
        callDatas[0] = abi.encode(module1);
        string memory description = "Add new module";

        (bool proposeSuccess, bytes memory proposeResult) = address(phoGovernanceDelegator).call(
            abi.encodeWithSignature(
                "propose(address[],uint256[],string[],bytes[],string)",
                targets,
                values,
                signatures,
                callDatas,
                description
            )
        );
        (uint256 proposalId) = abi.decode(proposeResult, (uint256));
        uint256 pidAfter = _getCurrentProposalId();
        address proposer = _getProposer(proposalId);
        (uint256 startBlock, uint256 endBlock) = _getProposalBlocks(proposalId);

        assertEq(proposer, owner);
        assertEq(proposalId, pidAfter);
        assertEq(startBlock, block.number + VOTING_DELAY);
        assertEq(endBlock, block.number + VOTING_DELAY + VOTING_PERIOD);

        vm.roll(block.number + VOTING_DELAY + 10);
        vm.stopPrank();

        return proposalId;
    }

    function testCastVote() public returns (uint256) {
        uint256 proposalId = testSetUpProposal();
        _vote(proposalId, user1, 1);
        (uint256 _against, uint256 _for, uint256 _abstain) = _getProposalVotes(proposalId);
        _endProposal(proposalId);
        assertEq(_getProposalState(proposalId), 4);
    }

    function testQueueProposal() public {
        uint256 proposalId = testSetUpProposal();
        _vote(proposalId, user1, 1);
        _endProposal(proposalId);
        _queue(proposalId);
        console.log(_getProposalState(proposalId));
        assertEq(_getProposalState(proposalId), 5);
    }

    function testExecuteProposal() public {
        (,,,,, IModuleManager.Status statusBefore) = moduleManager.modules(module1);
        uint256 proposalId = testSetUpProposal();
        _vote(proposalId, user1, 1);
        _endProposal(proposalId);
        _queue(proposalId);
        vm.warp(_getProposalETA(proposalId) + 1 hours);
        _execute(proposalId);

        (,,,,, IModuleManager.Status statusAfter) = moduleManager.modules(module1);
        assertEq(uint8(statusBefore), 0);
        assertEq(uint8(statusAfter), 1);
    }

    function _execute(uint256 proposalId) public {
        address(phoGovernanceDelegator).call(
            abi.encodeWithSignature("execute(uint256)", proposalId)
        );
    }

    function _vote(uint256 proposalId, address user, uint8 vote) private {
        vm.prank(user);
        address(phoGovernanceDelegator).call(
            abi.encodeWithSignature("castVote(uint256,uint8)", proposalId, vote)
        );
    }

    function _endProposal(uint256 proposalId) private {
        (, uint256 end) = _getProposalBlocks(proposalId);
        vm.roll(end + 10);
    }

    function _queue(uint256 proposalId) private {
        address(phoGovernanceDelegator).call(abi.encodeWithSignature("queue(uint256)", proposalId));
    }

    function _getCurrentProposalId() private returns (uint256) {
        (, bytes memory data) =
            address(phoGovernanceDelegator).call(abi.encodeWithSignature("proposalCount()"));
        return abi.decode(data, (uint256));
    }

    function _getProposalData(uint256 proposalId) private returns (bytes memory) {
        (, bytes memory data) = address(phoGovernanceDelegator).call(
            abi.encodeWithSignature("proposals(uint256)", proposalId)
        );
        return data;
    }

    function _getProposer(uint256 proposalId) private returns (address proposer) {
        bytes memory data = _getProposalData(proposalId);
        assembly {
            proposer := mload(add(data, 64))
        }
    }

    function _getProposalETA(uint256 proposalId) private returns (uint256 eta) {
        bytes memory data = _getProposalData(proposalId);
        assembly {
            eta := mload(add(data, 96))
        }
    }

    function _getProposalVotes(uint256 proposalId)
        private
        returns (uint256 _against, uint256 _for, uint256 _abstain)
    {
        bytes memory data = _getProposalData(proposalId);
        assembly {
            _against := mload(add(data, 192))
            _for := mload(add(data, 224))
            _abstain := mload(add(data, 256))
        }
    }

    function _getProposalBlocks(uint256 proposalId) private returns (uint256 start, uint256 end) {
        bytes memory data = _getProposalData(proposalId);
        assembly {
            start := mload(add(data, 128))
            end := mload(add(data, 160))
        }
    }

    function _getProposalState(uint256 proposalId) private returns (uint256) {
        (, bytes memory data) = address(phoGovernanceDelegator).call(
            abi.encodeWithSignature("state(uint256)", proposalId)
        );
        return abi.decode(data, (uint256));
    }
}
