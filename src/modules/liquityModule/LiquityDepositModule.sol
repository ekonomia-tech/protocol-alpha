// // SPDX-License-Identifier: GPL-3.0-or-later

// pragma solidity ^0.8.13;

// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
// import "../interfaces/IModuleAMO.sol";
// import "./LiquityModuleAMO.sol";
// import "@modules/stablecoinDepositModule/StablecoinDepositModuleBase.sol";

// /// @title LiquityDepositModule
// /// @author Ekonomia: https://github.com/ekonomia-tech
// /// @notice Accepts LUSD 1:1 and uses Liquity StabilityPool for AMO
// contract LiquityDepositModule is StablecoinDepositModuleBase {
//     using SafeERC20 for IERC20Metadata;

//     /// Errors
//     error CannotDepositZero();
//     error CannotRedeemZeroTokens();

//     /// Events
//     event Deposited(address indexed depositor, uint256 depositAmount, uint256 phoMinted);
//     event Redeemed(address indexed redeemer, uint256 redeemAmount);

//     /// State vars
//     IModuleAMO public liquityModuleAMO;

//     /// Constructor
//     constructor(
//         address _moduleManager,
//         address _stablecoin,
//         address _pho,
//         address _stakingToken,
//         address _rewardToken
//     ) StablecoinDepositModuleBase(_moduleManager, _stablecoin, _pho) {
//         liquityModuleAMO = new LiquityModuleAMO(
//             "Photon Liquity AMO",
//             "LQTY-AMO",
//             _stakingToken,
//             _rewardToken,
//             msg.sender,
//             address(this),
//             _stablecoin
//         );
//     }

//     /// @notice user deposits their stablecoin
//     /// @param depositAmount deposit amount (in stablecoin decimals)
//     function deposit(uint256 depositAmount) external override nonReentrant {
//         if (depositAmount == 0) {
//             revert CannotDepositZero();
//         }
//         // Call AMO - which transfers LUSD from caller
//         liquityModuleAMO.stakeFor(msg.sender, depositAmount);
//         issuedAmount[msg.sender] += depositAmount;
//         moduleManager.mintPHO(msg.sender, depositAmount);

//         // pho minted == depositAmount, since 1 to 1 with LUSD
//         emit Deposited(msg.sender, depositAmount, depositAmount);
//     }

//     /// @notice user redeems PHO for LUSD
//     function redeem() external nonReentrant {
//         uint256 redeemAmount = issuedAmount[msg.sender];
//         if (redeemAmount == 0) {
//             revert CannotRedeemZeroTokens();
//         }
//         issuedAmount[msg.sender] -= redeemAmount;
//         moduleManager.burnPHO(msg.sender, redeemAmount);

//         // Note: Always a full withdrawal
//         liquityModuleAMO.withdrawAllFor(msg.sender);
//         emit Redeemed(msg.sender, redeemAmount);
//     }
// }
