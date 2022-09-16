// SPDX-License-Identifier: GPL-3.0-or-later

import "../interfaces/IPHO.sol";
import "../interfaces/ITeller.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity ^0.8.13;

/// @title gateway contract for minting $PHO
/// @author Ekonomia: https://github.com/ekonomia-tech

contract Teller is ITeller, Ownable {
    IPHO public pho;

    uint256 public mintCeiling;
    uint256 public totalPHOMinted; // TODO - We need to hook up the revoking and deleting to the totalPHOMinted. And start decrementing the totalPHOMinted. Otherwise this will get out of sync with the actual PHO minted, and it will become meaningless.

    /// whitelisted contracts that can ask the Teller to mint
    mapping(address => uint256) public whitelist;

    /// tracks max $PHO that whitelisted accounts can ask for
    mapping(address => uint256) public mintingBalances;

    constructor(address _phoAddress, uint256 _mintCeiling) {
        pho = IPHO(_phoAddress);
        mintCeiling = _mintCeiling;
    }

    /// @notice minting function for $PHO. only accessible to approved addresses
    /// @param to the user to mint $PHO to
    /// @param amount the amount of $PHO to mint
    function mintPHO(address to, uint256 amount) external {
        require(to != address(0), "Teller: zero address detected");
        require(whitelist[msg.sender] > 0, "Teller: caller is not approved");
        require(totalPHOMinted + amount <= mintCeiling, "Teller: ceiling reached");
        require(
            mintingBalances[msg.sender] + amount <= whitelist[msg.sender],
            "Teller: caller ceiling reached"
        );
        totalPHOMinted += amount;
        mintingBalances[msg.sender] += amount;
        pho.mint(to, amount);
    }

    /// @notice function to approve addresses of minting rights
    /// @param caller the requesting address to be approved minting rights
    /// @param ceiling the minting ceiling for the caller
    function whitelistCaller(address caller, uint256 ceiling) external onlyOwner {
        require(caller != address(0), "Teller: zero address detected");
        require(ceiling > 0, "Teller: zero value detected");
        require(whitelist[caller] == 0, "Teller: caller is already approved");
        whitelist[caller] = ceiling;
        emit CallerWhitelisted(caller, ceiling);
    }

    // TODO - We need to hook up the revoking and deleting to the totalPHOMinted. And start decrementing the totalPHOMinted.
    /// @notice function to revoke addresses of minting rights
    /// @param caller the address to be revoked minting rights
    function revokeCaller(address caller) external onlyOwner {
        require(caller != address(0), "Teller: zero address detected");
        require(whitelist[caller] > 0, "Teller: caller is not approved");
        delete whitelist[caller];
        delete mintingBalances[caller];
        emit CallerRevoked(caller);
    }

    /// @notice modify the caller's minting ceiling
    /// @param caller the address to modify it's ceiling
    /// @param newCeiling the new minting ceiling for the caller
    function modifyCallerCeiling(address caller, uint256 newCeiling) external onlyOwner {
        require(caller != address(0), "Teller: zero address detected");
        require(whitelist[caller] > 0, "Teller: caller is not approved");
        require(mintingBalances[caller] < newCeiling, "Teller: new ceiling too low");
        whitelist[caller] = newCeiling;
        emit CallerCeilingModified(caller, newCeiling);
    }

    /// @notice set a new $PHO minting ceiling for the Teller
    /// @param newCeiling the max amount of $PHO that the Teller can mint
    function setPHOCeiling(uint256 newCeiling) external onlyOwner {
        require(newCeiling > 0, "Teller: new ceiling cannot be 0");
        require(newCeiling != mintCeiling, "Teller: same ceiling value detected");
        require(newCeiling > totalPHOMinted, "Teller: new ceiling too low");
        mintCeiling = newCeiling;
        emit PHOCeilingSet(mintCeiling);
    }
}
