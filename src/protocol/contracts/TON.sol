// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20VotesComp.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TON is ERC20Burnable, ERC20VotesComp {
    uint256 public constant genesis_supply = 100000000 * 10 ** 18;

    constructor(string memory _name, string memory _symbol)
        ERC20(_name, _symbol)
        ERC20Permit(_name)
    {
        _mint(msg.sender, genesis_supply);
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
