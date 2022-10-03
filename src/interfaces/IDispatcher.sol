// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

interface IDispatcher {
    event TellerUpdated(address indexed tellerAddress);
    event VaultAdded(address indexed vault);
    event VaultRemoved(address indexed vault);
    event Dispatched(
        address indexed user, address indexed collateralToken, uint256 collateralIn, uint256 phoOut
    );
    event Redeemed(
        address indexed user, address indexed collateralToken, uint256 phoIn, uint256 collateralOut
    );

    function dispatchCollateral(address tokenIn, uint256 amountIn, uint256 minPHOOut) external;
    function redeemPHO(address tokenOut, uint256 amount, uint256 minCollateralOut) external;
    function addVault(address vault) external;
    function removeVault(address vault) external;
    function setTeller(address tellerAddress) external;
}
