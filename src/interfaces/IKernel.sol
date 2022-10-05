// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IKernel {
    event CallerWhitelisted(address indexed caller, uint256 ceiling);
    event CallerRevoked(address indexed caller);
    event CallerCeilingModified(address indexed caller, uint256 newCeiling);

    function mintPHO(address to, uint256 amount) external;
    function whitelistCaller(address caller, uint256 ceiling) external;
    function revokeCaller(address caller) external;
    function modifyCallerCeiling(address caller, uint256 newCeiling) external;
}
