// SPDX-License-Identifier: GPL-3.0-or-later
// Inspired by Frax
// https://github.com/FraxFinance/frax-solidity/blob/7cbe89981ffa5d3cd0eeaf62dd1489c3276de0e4/src/hardhat/contracts/FXS/FXS.sol
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/ITON.sol";

contract TON is ITON, ERC20Burnable {
    uint256 public constant genesis_supply = 100000000 * 10 ** 18;

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        _mint(msg.sender, genesis_supply);
    }

    /// @notice $TON burning function. can only be executed by controller or gov or owner
    /// @param from the user to burn $TON from
    /// @param amount the amount of $TON to burn
    function burn(address from, uint256 amount) external {
        super.burnFrom(from, amount);
        emit TONBurned(from, amount);
    }
}
