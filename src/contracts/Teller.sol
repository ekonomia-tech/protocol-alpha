// SPDX-License-Identifier: GPL-3.0-or-later

import "../interfaces/IPHO.sol";
import "../interfaces/ITON.sol";
import "../interfaces/ITeller.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity ^0.8.13;

/// @title gateway contract for minting $PHO
/// @author Ekonomia: https://github.com/ekonomia-tech

contract Teller is ITeller, Ownable {
    address public timelockAddress;
    address public controllerAddress;
    IPHO public pho;

    uint256 public phoCeiling;
    uint256 public totalPHOMinted;

    /// the approved caller list
    mapping(address => bool) public approvedCallers;

    /// tracks how much each approved caller have minted in $PHO
    mapping(address => uint256) public mintingBalances;

    modifier onlyByOwnerGovernanceOrController() {
        require(
            msg.sender == owner() || msg.sender == timelockAddress
                || msg.sender == controllerAddress,
            "Teller: Not the owner, controller, or the governance timelock"
        );
        _;
    }

    modifier onlyApprovedCallers() {
        require(approvedCallers[msg.sender], "Teller: caller is not approved");
        _;
    }

    constructor(
        address _controllerAddress,
        address _timelockAddress,
        address _phoAddress,
        uint256 _phoCeiling
    ) {
        timelockAddress = _timelockAddress;
        controllerAddress = _controllerAddress;
        pho = IPHO(_phoAddress);
        phoCeiling = _phoCeiling;
    }

    /// @notice minting function for $PHO. only accessible to approved addresses
    /// @param to the user to mint $PHO to
    /// @param amount the amount of $PHO to mint
    function mintPHO(address to, uint256 amount) external onlyApprovedCallers {
        require(to != address(0), "Teller: zero address detected");
        require(totalPHOMinted + amount <= phoCeiling, "Teller: ceiling reached");
        totalPHOMinted += amount;
        mintingBalances[msg.sender] += amount;
        pho.mint(to, amount);
    }

    /// @notice function to approve addresses of minting rights
    /// @param caller the requesting address to be approved minting rights
    function approveCaller(address caller) external onlyByOwnerGovernanceOrController {
        require(caller != address(0), "Teller: zero address detected");
        require(approvedCallers[caller] == false, "Teller: caller is already approved");
        approvedCallers[caller] = true;
        emit CallerApproved(caller);
    }

    /// @notice function to revoke addresses of minting rights
    /// @param caller the address to be revoked minting rights
    function revokeCaller(address caller) external onlyByOwnerGovernanceOrController {
        require(caller != address(0), "Teller: zero address detected");
        require(approvedCallers[caller], "Teller: caller is not approved");
        delete approvedCallers[caller];
        emit CallerRevoked(caller);
    }

    /// @notice set a new $PHO minting ceiling for this teller
    /// @param newCeiling the max amount of $PHO that this teller can mint
    function setPHOCeiling(uint256 newCeiling) external onlyByOwnerGovernanceOrController {
        require(newCeiling > 0, "Teller: new ceiling cannot be 0");
        require(newCeiling != phoCeiling, "Teller: same ceiling value detected");
        phoCeiling = newCeiling;
        emit PHOCeilingSet(phoCeiling);
    }

    /// @notice set controller (owner) of this contract
    /// @param newController the new controller address
    function setController(address newController) external onlyByOwnerGovernanceOrController {
        require(newController != address(0), "Teller: zero address detected");
        require(newController != controllerAddress, "Teller: same address detected");
        controllerAddress = newController;
        emit ControllerSet(controllerAddress);
    }

    /// @notice set the timelock address to be used in this contract
    /// @param newTimelock the new timelock address
    function setTimelock(address newTimelock) external onlyByOwnerGovernanceOrController {
        require(newTimelock != address(0), "Teller: zero address detected");
        require(newTimelock != timelockAddress, "Teller: same address detected");
        timelockAddress = newTimelock;
        emit TimelockSet(timelockAddress);
    }
}
