// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20VotesComp.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@protocol/interfaces/ITON.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

/// @title PHOTON protocol stablecoin
/// @author Ekonomia: https://github.com/Ekonomia
contract TON is ITON, ERC20Burnable, ERC20VotesComp, Ownable {
    address public kernel;

    modifier onlyKernel() {
        require(kernel == msg.sender, "TON: caller is not the kernel");
        _;
    }

    constructor(string memory _name, string memory _symbol)
        ERC20(_name, _symbol)
        ERC20Permit(_name)
    {}

    /// @notice mint new $TON tokens
    /// @param to the user to mint $TON to
    /// @param amount the amount to mint
    function mint(address to, uint256 amount) external onlyKernel {
        _mint(to, amount);
    }

    function burnFrom(address account, uint256 amount) public override (ITON, ERC20Burnable) {
        super.burnFrom(account, amount);
    }

    /// @notice set the kernel address, which will be the only address capable of minting
    function setKernel(address newKernel) external onlyOwner {
        require(newKernel != address(0), "TON: zero address detected");
        require(newKernel != kernel, "TON: same address detected");
        kernel = newKernel;
        emit KernelSet(kernel);
    }

    /**
     * @dev Move voting power when tokens are transferred.
     *
     * Emits a {DelegateVotesChanged} event.
     */
    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        virtual
        override (ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    /**
     * @dev Snapshots the totalSupply after it has been decreased.
     */
    function _burn(address account, uint256 amount) internal virtual override (ERC20, ERC20Votes) {
        super._burn(account, amount);
    }

    /**
     * @dev Snapshots the totalSupply after it has been increased.
     */
    function _mint(address account, uint256 amount) internal virtual override (ERC20, ERC20Votes) {
        super._mint(account, amount);
    }
}
