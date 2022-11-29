// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@modules/stablecoinDepositModule/StablecoinDepositModuleBase.sol";

/// @title StablecoinDepositModule
/// @author Ekonomia: https://github.com/ekonomia-tech
/// @notice Accepts specific stablecoin 1:1 i.e. USDC, DAI, etc.
contract StablecoinDepositModule is StablecoinDepositModuleBase {
    using SafeERC20 for IERC20Metadata;

    /// Events
    event Deposited(address indexed depositor, uint256 depositAmount, uint256 phoMinted);
    event Redeemed(address indexed redeemer, uint256 redeemAmount, uint256 stablecoinTransferred);

    /// Constructor
    constructor(address _moduleManager, address _stablecoin, address _pho)
        StablecoinDepositModuleBase(_moduleManager, _stablecoin, _pho)
    {}

    /// @notice user deposits their stablecoin
    /// @param depositAmount deposit amount (in stablecoin decimals)
    function deposit(uint256 depositAmount) external override nonReentrant {
        // scale if decimals < 18
        uint256 scaledDepositAmount = depositAmount;
        scaledDepositAmount = depositAmount * (10 ** (18 - stablecoinDecimals));

        // transfer stablecoin from caller
        stablecoin.safeTransferFrom(msg.sender, address(this), depositAmount);

        issuedAmount[msg.sender] += scaledDepositAmount;

        // mint PHO
        moduleManager.mintPHO(msg.sender, scaledDepositAmount);
        emit Deposited(msg.sender, depositAmount, scaledDepositAmount);
    }

    /// @notice user redeems PHO for their original stablecoin
    /// @param redeemAmount redeem amount in terms of PHO, which is 18 decimals
    function redeem(uint256 redeemAmount) external override nonReentrant {
        if (redeemAmount > issuedAmount[msg.sender]) {
            revert CannotRedeemMoreThanDeposited();
        }

        issuedAmount[msg.sender] -= redeemAmount;

        // burn PHO
        moduleManager.burnPHO(msg.sender, redeemAmount);

        // scale if decimals < 18
        uint256 scaledRedeemAmount = redeemAmount;
        scaledRedeemAmount = redeemAmount / (10 ** (18 - stablecoinDecimals));

        // transfer stablecoin to caller
        stablecoin.transfer(msg.sender, scaledRedeemAmount);
        emit Redeemed(msg.sender, redeemAmount, scaledRedeemAmount);
    }
}
