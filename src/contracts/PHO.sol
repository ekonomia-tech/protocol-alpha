// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IPHO.sol";

/// @title PHOTON protocol stablecoin
/// @author Ekonomia: https://github.com/Ekonomia

contract PHO is IPHO, ERC20Burnable, Ownable {
    address public teller;

    modifier onlyTeller() {
        require(teller == msg.sender, "PHO: caller is not the teller");
        _;
    }

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

    /// @notice mint new $PHO tokens
    /// @param to the user to mint $PHO to
    /// @param amount the amount to mint
    function mint(address to, uint256 amount) external onlyTeller {
        super._mint(to, amount);
    }

    /// @notice set the teller address, which will be the only address capable of minting
    function setTeller(address newTeller) external onlyOwner {
        require(newTeller != address(0), "PHO: zero address detected");
        require(newTeller != teller, "PHO: same address detected");
        teller = newTeller;
        emit TellerSet(teller);
    }
}
