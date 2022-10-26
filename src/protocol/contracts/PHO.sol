// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20VotesComp.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@protocol/interfaces/IPHO.sol";

/// @title PHOTON protocol stablecoin
/// @author Ekonomia: https://github.com/Ekonomia
// TODO - not sure if we can work with OZ extensions to achieve the same type of token type here. The question is that we would have to set up PHO && TON like so: contract PHO is IPHO, ERC20VotesComp {} <-- The issue here is that I'm not sure if we would have to have one extension only. Can we also have ERC20Burnable? It seems weird to me that OZ would design their contracts in a way that you could only have one extension. But it looks, based off of the errors I'm seeing coming up when trying to inherit both, that is the case.  If so, it looks like ERC20Burnable doesn't have a lot to it though, so we can just add those functions into the PHO && TON implementation contracts directly. 
contract PHO is IPHO, ERC20VotesComp, ERC20Burnable, Ownable {
    address public kernel;

    modifier onlyKernel() {
        require(kernel == msg.sender, "PHO: caller is not the kernel");
        _;
    }

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

    /// @notice mint new $PHO tokens
    /// @param to the user to mint $PHO to
    /// @param amount the amount to mint
    function mint(address to, uint256 amount) external onlyKernel {
        super._mint(to, amount);
    }

    function burnFrom(address account, uint256 amount) public override (ERC20Burnable, IPHO) {
        super.burnFrom(account, amount);
    }

    /// @notice set the kernel address, which will be the only address capable of minting
    function setKernel(address newKernel) external onlyOwner {
        require(newKernel != address(0), "PHO: zero address detected");
        require(newKernel != kernel, "PHO: same address detected");
        kernel = newKernel;
        emit KernelSet(kernel);
    }
}
