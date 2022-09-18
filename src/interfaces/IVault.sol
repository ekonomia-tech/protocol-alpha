// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

interface IVault {
    event CallerWhitelisted(address indexed caller);
    event CallerRevoked(address indexed caller);

    function getVaultDollarValue() external view returns (uint256);
    function provide(uint256 amount) external;
    function getVaultToken() external view returns (address);
    function getTokenPriceUSD() external view returns (uint256);
    function whitelistCaller(address caller) external;
    function revokeCaller(address caller) external;
}
