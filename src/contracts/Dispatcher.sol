// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/ITeller.sol";
import "../interfaces/IDispatcher.sol";
import "../interfaces/IVault.sol";
import "./PHO.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title Dispatcher contract
/// @author Ekonomia: https://github.com/Ekonomia

contract Dispatcher is IDispatcher, Ownable {
    ITeller public teller;
    IPHO public pho;

    /// token => vault address
    mapping(address => address) public vaults;
    uint256 public constant PRICE_PRECISION = 10 ** 6;

    /// @param _phoAddress the address of the $PHO token contract
    /// @param _tellerAddress the address of the minting privileged teller contract
    constructor(address _phoAddress, address _tellerAddress) {
        pho = IPHO(_phoAddress);
        teller = ITeller(_tellerAddress);
    }

    /// @notice mint 1 $PHO to 1 USD collateral value provided the collateral
    /// @param tokenIn the collateral token provided by the user
    /// @param amountIn the amount of collateral supplied by the user
    /// @param minPHOOut the minimum $PHO that the user is willing to accept
    function dispatchCollateral(address tokenIn, uint256 amountIn, uint256 minPHOOut) external {
        require(tokenIn != address(0), "Dispatcher: zero address detected");
        require(amountIn != 0, "Dispatcher: zero value detected");
        require(vaults[tokenIn] != address(0), "Dispatcher: token not accepted");

        IVault vault = IVault(vaults[tokenIn]);
        IERC20Metadata collateral = IERC20Metadata(tokenIn);

        uint256 collateralPrice = vault.getTokenPriceUSD();
        uint256 collateralAmount_d18 = amountIn * (10 ** (pho.decimals() - collateral.decimals()));
        uint256 phoAmountOut = collateralAmount_d18 * collateralPrice / PRICE_PRECISION;

        require(phoAmountOut > minPHOOut, "Dispatcher: max slippage reached");

        collateral.transferFrom(msg.sender, address(vault), amountIn);
        teller.mintPHO(msg.sender, phoAmountOut);

        emit Dispatched(msg.sender, tokenIn, amountIn, phoAmountOut);
    }

    /// @notice redeem 1 $PHO to 1 USD collateral value and claim collateral
    /// @param tokenOut the collateral token in which the user wishes to redeem for
    /// @param amountIn the amount of $PHO the user wants to redeem
    /// @param minCollateralOut the minimum collateral the user is willing to get for the $PHO provided
    function redeemPHO(address tokenOut, uint256 amountIn, uint256 minCollateralOut) external {
        require(tokenOut != address(0), "Dispatcher: zero address detected");
        require(amountIn != 0, "Dispatcher: zero value detected");
        require(vaults[tokenOut] != address(0), "Dispatcher: token not accepted");

        IVault vault = IVault(vaults[tokenOut]);
        IERC20Metadata collateral = IERC20Metadata(tokenOut);

        uint256 collateralPrice = vault.getTokenPriceUSD();
        uint256 phoAmountPrecision = amountIn / (10 ** (pho.decimals() - collateral.decimals()));
        uint256 collateralNeeded = phoAmountPrecision * PRICE_PRECISION / collateralPrice;

        require(
            collateralNeeded <= collateral.balanceOf(address(vault)), "Dispatcher: vault too low"
        );
        require(collateralNeeded >= minCollateralOut, "Dispatcher: max slippage reached");

        pho.burnFrom(msg.sender, amountIn);
        vault.provideTo(msg.sender, collateralNeeded);

        emit Redeemed(msg.sender, tokenOut, amountIn, collateralNeeded);
    }

    /// @notice add vault to the vaults list this dispatcher can communicate with
    /// @param vaultToAdd the vault address to add to the vaults mapping
    function addVault(address vaultToAdd) external onlyOwner {
        require(vaultToAdd != address(0), "Dispatcher: zero address detected");
        address vaultToken = IVault(vaultToAdd).getVaultToken();
        require(vaults[vaultToken] == address(0), "Dispatcher: vault already added");
        vaults[vaultToken] = vaultToAdd;
        emit VaultAdded(vaultToAdd);
    }

    /// @notice remove a vault from the vaults list
    /// @param vaultToRemove the vault address to be removed from the vaults mapping
    function removeVault(address vaultToRemove) external onlyOwner {
        require(vaultToRemove != address(0), "Dispatcher: zero address detected");
        address vaultToken = IVault(vaultToRemove).getVaultToken();
        require(vaults[vaultToken] != address(0), "Dispatcher: vault not registered");
        delete vaults[vaultToken];
        emit VaultRemoved(vaultToRemove);
    }

    /// @notice setting the teller address that the dispatcher requests minting from
    /// @param tellerAddress the address of the teller to be set
    function setTeller(address tellerAddress) external onlyOwner {
        require(tellerAddress != address(0), "Dispatcher: zero address detected");
        require(tellerAddress != address(teller), "Dispatcher: same address detected");
        teller = ITeller(tellerAddress);
        emit TellerUpdated(tellerAddress);
    }
}
