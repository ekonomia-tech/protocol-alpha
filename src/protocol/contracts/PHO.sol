// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20VotesComp.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@protocol/interfaces/IPHO.sol";

/// @title PHOTON protocol stablecoin
/// @author Ekonomia: https://github.com/Ekonomia

contract PHO is IPHO, ERC20VotesComp, Ownable {
    address public kernel;

    modifier onlyKernel() {
        require(kernel == msg.sender, "PHO: caller is not the kernel");
        _;
    }

    constructor(string memory _name, string memory _symbol)
        ERC20(_name, _symbol)
        ERC20Permit(_name)
    {}

    /// @notice mint new $PHO tokens
    /// @param to the user to mint $PHO to
    /// @param amount the amount to mint
    function mint(address to, uint256 amount) external onlyKernel {
        _mint(to, amount);
    }

    /// @notice set the kernel address, which will be the only address capable of minting
    function setKernel(address newKernel) external onlyOwner {
        require(newKernel != address(0), "PHO: zero address detected");
        require(newKernel != kernel, "PHO: same address detected");
        kernel = newKernel;
        emit KernelSet(kernel);
    }

    /// @notice Destroys `amount` tokens from `account`, deducting from the caller's
    /// @param account - account to burn from
    /// @param amount - amount to burn
    /// NOTE - function taken from OpenZeppelin ERC20Burnable contract
    function burnFrom(address account, uint256 amount) public virtual {
        _spendAllowance(account, _msgSender(), amount);
        _burn(account, amount);
    }
}
