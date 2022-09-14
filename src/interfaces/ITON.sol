// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

interface ITON {
    event TONBurned(address indexed from, uint256 amount);
    event TimelockSet(address indexed newTimelockAddress);
    event ControllerSet(address indexed controllerAddress);

    function setTimelock(address timelockAddress) external;
    function setController(address newController) external;
    function burn(address from, uint256 amount) external;
}
