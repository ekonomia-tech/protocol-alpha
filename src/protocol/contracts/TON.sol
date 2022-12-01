// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TON is ERC20Burnable {
    uint256 public constant genesis_supply = 100000000 * 10 ** 18;

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        _mint(msg.sender, genesis_supply);
    }
}
