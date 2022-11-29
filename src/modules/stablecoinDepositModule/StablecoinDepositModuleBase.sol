// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@protocol/interfaces/IPHO.sol";
import "@protocol/interfaces/IModuleManager.sol";

/// @title StablecoinDepositModuleBase
/// @author Ekonomia: https://github.com/ekonomia-tech
/// @notice Accepts specific stablecoin 1:1 i.e. USDC, DAI, etc.
abstract contract StablecoinDepositModuleBase is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20Metadata;

    /// Errors
    error ZeroAddressDetected();
    error CannotRedeemMoreThanDeposited();
    error OverEighteenDecimals();

    /// State vars
    IModuleManager public moduleManager;
    IERC20Metadata public stablecoin;
    uint256 public stablecoinDecimals;
    IPHO public pho;
    mapping(address => uint256) public issuedAmount;

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
    }

    /// @notice user deposits their stablecoin
    /// @param depositAmount deposit amount (in stablecoin decimals)
    function deposit(uint256 depositAmount) external virtual nonReentrant {}

    /// @notice user redeems PHO for their original stablecoin
    /// @param redeemAmount redeem amount in terms of PHO, which is 18 decimals
    function redeem(uint256 redeemAmount) external virtual nonReentrant {}
}
