// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPHO is IERC20 {
    event PHOBurned(address indexed from, address indexed burnCaller, uint256 amount);
    event PHOMinted(address indexed mintCaller, address indexed to, uint256 amount);
    event TellerSet(address teller);
    event ControllerSet(address controllerAddress);
    event TimelockSet(address timelockAddress);

    function burn(address from, uint256 amount) external;
    function mint(address to, uint256 amount) external;
    function setTeller(address newTeller) external;
    function setController(address newController) external;
    function setTimelock(address newTimelock) external;
}
