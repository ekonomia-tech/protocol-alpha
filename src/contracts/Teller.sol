// SPDX-License-Identifier: GPL-3.0-or-later

import "../interfaces/IPHO.sol";
import "../interfaces/ITON.sol";
import "../interfaces/ITeller.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity ^0.8.13;

contract Teller is ITeller, Ownable {
    address public timelockAddress;
    address public controllerAddress;
    IPHO public pho;
    ITON public ton;

    uint256 public phoCeiling;
    uint256 public totalPHOMinted;

    /// the approved caller list
    mapping(address => bool) public approved;

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

    modifier onlyApproved() {
        require(approved[msg.sender], "Teller: caller is not approved");
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
    function mintPHO(address to, uint256 amount) external onlyApproved {
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
        approved[caller] = true;
        emit CallerApproved(caller);
    }

    /// @notice function to revoke addresses of minting rights
    /// @param caller the address to be revoked minting rights
    function revokeCaller(address caller) external onlyByOwnerGovernanceOrController {
        require(caller != address(0), "Teller: zero address detected");
        delete approved[caller];
        emit CallerRevoked(caller);
    }

    /// @notice set a new $PHO minting ceiling for this teller
    /// @param newCeiling the max amount og $PHO that this teller can mint
    function setPHOCeiling(uint256 newCeiling) external onlyByOwnerGovernanceOrController {
        require(newCeiling > 0, "Teller: new ceiling cannot be 0");
        phoCeiling = newCeiling;
        emit PHOCeilingSet(phoCeiling);
    }

    /// @notice set controller (owner) of this contract
    function setController(address newController) external onlyByOwnerGovernanceOrController {
        require(newController != address(0), "PHO: zero address detected");
        controllerAddress = newController;
        emit ControllerSet(controllerAddress);
    }

    /// @notice set the timelock address to be used in this contract
    function setTimelock(address newTimelock) external onlyByOwnerGovernanceOrController {
        require(newTimelock != address(0), "PHO: zero address detected");
        timelockAddress = newTimelock;
        emit TimelockSet(timelockAddress);
    }
}
