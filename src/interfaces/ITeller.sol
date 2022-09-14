// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface ITeller {
    event ControllerSet(address indexed controllerAddress);
    event TimelockSet(address indexed timelockAddress);
    event CallerApproved(address indexed caller);
    event CallerRevoked(address indexed caller);
    event PHOCeilingSet(uint256 ceiling);

    function mintPHO(address to, uint256 amount) external;
    function approveCaller(address caller) external;
    function revokeCaller(address caller) external;
    function setController(address controllerAddress) external;
    function setTimelock(address timelockAddress) external;
    function setPHOCeiling(uint256 ceiling) external;
}
