// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "../BaseSetup.t.sol";
import "@governance/PHOGovernorBravoDelegate.sol";
import "@governance/PHOGovernorBravoDelegator.sol";
import {TONGovernorBravoDelegate} from "@governance/TONGovernorBravoDelegate.sol";
import {TONGovernorBravoDelegator} from "@governance/TONGovernorBravoDelegator.sol";

contract GovernanceTest is BaseSetup {
    error UnrecognizedProxy();

    PHOGovernorBravoDelegate public phoGovernanceDelegate;
    PHOGovernorBravoDelegator public phoGovernanceDelegator;
    TONGovernorBravoDelegate public tonGovernanceDelegate;
    TONGovernorBravoDelegator public tonGovernanceDelegator;

    address public PHO_timelock_address = address(100);
    address public TON_timelock_address = address(103);

    uint256 public constant VOTING_DELAY = 14400;
    uint256 public constant VOTING_PERIOD = 21600;

    function setUp() public {
        phoGovernanceDelegate = new PHOGovernorBravoDelegate();

        phoGovernanceDelegator = new PHOGovernorBravoDelegator(
            PHO_timelock_address,
            address(pho),
            owner,
            address(phoGovernanceDelegate),
            VOTING_PERIOD,
            VOTING_DELAY,
            ONE_HUNDRED_D18
        );

        PHOGovernance = address(phoGovernanceDelegator);

        vm.prank(owner);
        address(phoGovernanceDelegator).call(
            abi.encodeWithSignature("_initiate(address)", address(0))
        );

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

    // function testSetPHOCeiling() public {
    //     _setUpAddedModule();

    //     vm.startPrank(owner);

    //     address[] memory targets = new address[](1);
    //     targets[0] = address(moduleManager);
    //     uint256[] memory values = new uint256[](1);
    //     values[0] = 0;
    //     string[] memory signatures = new string[](1);
    //     signatures[0] = "setPHOCeilingForModule(address _module, uint256 _newPHOCeiling)";
    //     bytes[] memory callDatas = new bytes[](1);
    //     callDatas[0] =
    //         abi.encode("address _module, uint256 _newPHOCeiling", module1, ONE_MILLION_D18);
    //     string memory description = "Set PHOCeiling for new module";

    //     _propose(TONGovernance, targets, values, signatures, callDatas, description);

    //     uint256 proposalStartBlock = block.number;

    //     // check that proposal is set up well and get the proposalID.
    //     (bool newInitialProposalIdSuccess, bytes memory newInitialProposalIdResult) =
    //         TONGovernance.call(abi.encodeWithSignature("initialProposalId()"));

    //     uint256 newInitialProposalId = abi.decode(newInitialProposalIdResult, (uint256));

    //     // next, cast votes to get proposal to succeed
    //     _castVote(TONGovernance, newInitialProposalId, 1);

    //     // next, roll forward duration of proposal && queue
    //     vm.roll(proposalStartBlock + VOTING_PERIOD + 1);
    //     _queue(TONGovernance, newInitialProposalId);
    //     _execute(TONGovernance, newInitialProposalId);

    //     vm.stopPrank();
    // }

    function testSetUpProposal() public returns (uint256) {
        vm.startPrank(owner);

        address[] memory targets = new address[](1);
        targets[0] = address(moduleManager);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        string[] memory signatures = new string[](1);
        signatures[0] = "addModule(address)";
        bytes[] memory callDatas = new bytes[](1);
        callDatas[0] = abi.encode(("address"), (module1));
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
        (uint256 _against,uint256 _for,uint256 _abstain) = _getProposalVotes(proposalId);
        _endProposal(proposalId);
        assertEq(_getProposalState(proposalId), 4);
    } 

    function testQueueProposal() public {
        uint256 proposalId = testSetUpProposal();
        _vote(proposalId, user1, 1);
        _endProposal(proposalId);
        _queue(proposalId);
    }

    function _vote(uint256 proposalId, address user, uint8 vote) private {
        vm.prank(user);
        address(phoGovernanceDelegator).call(abi.encodeWithSignature("castVote(uint256,uint8)", proposalId, vote));
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

    function _getProposalVotes(uint256 proposalId) private returns (uint256 _against, uint256 _for, uint256 _abstain) {
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

    function _getProposalState(uint256 proposalId) private  returns (uint256) {
         (, bytes memory data) = address(phoGovernanceDelegator).call(
            abi.encodeWithSignature("state(uint256)", proposalId)
        );
        return abi.decode(data, (uint256));
    }

    function _queue(address _proxy, uint256 _proposalId) internal {
        address proxy;

        if (_proxy == PHOGovernance) {
            proxy = PHOGovernance;
        } else if (_proxy == TONGovernance) {
            proxy = TONGovernance;
        } else {
            revert UnrecognizedProxy();
        }

        (bool queueSuccess,) = proxy.call(abi.encodeWithSignature("queue(uint)", _proposalId));
    }
}
