// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@protocol/interfaces/IPHO.sol";
import "@protocol/interfaces/IModuleManager.sol";
import "../interfaces/IModuleAMO.sol";
import "./LiquityModuleAMO.sol";

/// @title LiquityDepositModule
/// @author Ekonomia: https://github.com/ekonomia-tech
/// @notice Accepts LUSD 1:1
contract LiquityDepositModule is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20Metadata;

    /// Errors
    error ZeroAddressDetected();
    error CannotRedeemMoreThanDeposited();
    error OverEighteenDecimals();

    /// Events
    event Deposited(address indexed depositor, uint256 depositAmount, uint256 phoMinted);
    event Redeemed(address indexed redeemer, uint256 redeemAmount);

    /// State vars
    IModuleManager public moduleManager;
    IERC20Metadata public stablecoin;
    uint256 public stablecoinDecimals;
    address public liquityModuleAMO;
    IPHO public pho;
    mapping(address => uint256) public issuedAmount;

    address public stakingToken = 0x5f98805A4E8be255a32880FDeC7F6728C6568bA0; // LUSD
    address rewardToken = 0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D; // LQTY

    IStabilityPool public stabilityPool = IStabilityPool(0x66017D22b0f8556afDd19FC67041899Eb65a21bb);

    modifier onlyModuleManager() {
        require(msg.sender == address(moduleManager), "Only ModuleManager");
        _;
    }

    /// Constructor
    constructor(address _moduleManager, address _stablecoin, address _pho) {
        if (_moduleManager == address(0) || _stablecoin == address(0) || _pho == address(0)) {
            revert ZeroAddressDetected();
        }
        moduleManager = IModuleManager(_moduleManager);
        stablecoin = IERC20Metadata(_stablecoin);
        stablecoinDecimals = stablecoin.decimals();
        if (stablecoinDecimals > 18) {
            revert OverEighteenDecimals();
        }
        pho = IPHO(_pho);

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
    function deposit(uint256 depositAmount) external nonReentrant {
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
