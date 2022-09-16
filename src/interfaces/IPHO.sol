// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPHO is IERC20 {
    event TellerSet(address indexed teller);

    function mint(address to, uint256 amount) external;
    function setTeller(address newTeller) external;
}
