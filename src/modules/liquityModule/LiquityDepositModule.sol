// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../interfaces/IModuleAMO.sol";
import "./LiquityModuleAMO.sol";
import "@modules/stablecoinDepositModule/StablecoinDepositModuleBase.sol";

/// @title LiquityDepositModule
/// @author Ekonomia: https://github.com/ekonomia-tech
/// @notice Accepts LUSD 1:1 and uses Liquity StabilityPool for AMO
contract LiquityDepositModule is StablecoinDepositModuleBase {
    using SafeERC20 for IERC20Metadata;

    /// Errors
    error CannotDepositZero();
    error CannotRedeemZeroTokens();

    /// Events
    event Deposited(address indexed depositor, uint256 depositAmount, uint256 phoMinted);
    event Redeemed(address indexed redeemer, uint256 redeemAmount);

    /// State vars
    address public liquityModuleAMO;
    address public stakingToken = 0x5f98805A4E8be255a32880FDeC7F6728C6568bA0; // LUSD
    address rewardToken = 0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D; // LQTY

    IStabilityPool public stabilityPool = IStabilityPool(0x66017D22b0f8556afDd19FC67041899Eb65a21bb);

    /// Constructor
    constructor(address _moduleManager, address _stablecoin, address _pho)
        StablecoinDepositModuleBase(_moduleManager, _stablecoin, _pho)
    {
        LiquityModuleAMO liquityModuleAMOInstance = new LiquityModuleAMO(
            "LQTY-AMO",
            "LQTYAMO",
            stakingToken,
            rewardToken,
            msg.sender,
            address(this),
            _stablecoin
        );

        liquityModuleAMO = address(liquityModuleAMOInstance);
    }

    /// @notice user deposits their stablecoin
    /// @param depositAmount deposit amount (in stablecoin decimals)
    function deposit(uint256 depositAmount) external override nonReentrant {
        if (depositAmount == 0) {
            revert CannotDepositZero();
        }
        uint256 scaledDepositAmount = depositAmount;

        // Call AMO - which transfers LUSD from caller
        IModuleAMO(liquityModuleAMO).stakeFor(msg.sender, depositAmount);

        issuedAmount[msg.sender] += scaledDepositAmount;

        // mint PHO
        moduleManager.mintPHO(msg.sender, scaledDepositAmount);

        emit Deposited(msg.sender, depositAmount, scaledDepositAmount);
    }

    /// @notice user redeems PHO for LUSD
    function redeem() external nonReentrant {
        uint256 redeemAmount = issuedAmount[msg.sender];
        if (redeemAmount == 0) {
            revert CannotRedeemZeroTokens();
        }

        issuedAmount[msg.sender] -= redeemAmount;

        // burn PHO
        moduleManager.burnPHO(msg.sender, redeemAmount);

        // scale if decimals < 18
        uint256 scaledRedeemAmount = redeemAmount;
        scaledRedeemAmount = redeemAmount / (10 ** (18 - stablecoinDecimals));

        // Note: Always a full withdrawal
        IModuleAMO(liquityModuleAMO).withdrawAllFor(msg.sender);

        emit Redeemed(msg.sender, redeemAmount);
    }
}
