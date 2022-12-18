// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IOwnership {
    function owner() external view returns (address);

    function futureOwner() external view returns (address);

    function commitTransferOwnership(address newOwner) external;

    function acceptTransferOwnership() external;
}
