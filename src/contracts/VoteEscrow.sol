// SPDX-License-Identifier: GPL-3.0-or-later
// Inspired by Frax
// https://github.com/FraxFinance/frax-solidity/blob/master/src/hardhat/contracts/FXS/veFXS_Solidity.sol.old#L83
pragma solidity 0.8.13;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract VoteEscrow is ReentrancyGuard {
    address public token; // TON

    address public admin;  // Can and will be a smart contract

    // veTON token related
    string public name;
    string public symbol;
    string public version;
    uint256 public decimals;

    // additional data types
    struct Point {
        int128 bias;
        int128 slope; // dweight / dt
        uint256 ts;
        uint256 blk; // block
    }

    struct LockedBalance {
        int128 amount;
        uint256 end;
    }
    
    constructor(address token_addr, string memory _name, string memory _symbol, string memory _version) {
        admin = msg.sender;
        token = token_addr;
        // point_history[0].blk = block.number;
        // point_history[0].ts = block.timestamp;
        // controller = msg.sender;
        // transfersEnabled = true;

        uint256 _decimals = ERC20Burnable(token_addr).decimals();
        assert(_decimals <= 255);
        decimals = _decimals;

        name = _name;
        symbol = _symbol;
        version = _version;
    }
}