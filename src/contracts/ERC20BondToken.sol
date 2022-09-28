// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title ERC20 bond token
/// @author Ekonomia: https://github.com/Ekonomia
/// @dev ERC20 tokens for fixed term bonds
contract ERC20BondToken is ERC20, Ownable {
    uint8 internal _decimals;
    ERC20 public underlying;
    uint48 public expiry;
    address public dispatcher;

    modifier onlyDispatcher() {
        require(
            msg.sender == dispatcher,
            "ERC20BondToken: caller is not the dispatcher"
        );
        _;
    }

    /// Constructor
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 __decimals,
        ERC20 _underlying,
        uint48 _expiry,
        address _dispatcher
    ) ERC20(_name, _symbol) {
        _decimals = __decimals;
        underlying = _underlying;
        dispatcher = _dispatcher;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /// @notice mint new bond tokens
    /// @param to the user to mint to
    /// @param amount the amount to mint
    function mint(address to, uint256 amount) external onlyDispatcher {
        super._mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyDispatcher {
        _burn(from, amount);
    }
}
