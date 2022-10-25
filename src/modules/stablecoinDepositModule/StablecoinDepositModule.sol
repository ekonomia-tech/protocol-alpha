// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@protocol/interfaces/IPHO.sol";
import "@protocol/interfaces/IModuleManager.sol";

/// @title StablecoinDepositModule
/// @author Ekonomia: https://github.com/ekonomia-tech
/// @notice Accepts specific stablecoin 1:1 i.e. LUSD, DAI, etc.
contract StablecoinDepositModule is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20Metadata;

    /// Errors
    error ZeroAddressDetected();
    error CannotRedeemMoreThanDeposited();
    error OverEighteenDecimals();

    /// Events
    event StablecoinDeposited(address indexed depositor, uint256 depositAmount);
    event PHORedeemed(address indexed redeemer, uint256 redeemAmount);

    /// State vars
    IModuleManager public moduleManager;
    IERC20Metadata public stablecoin;
    uint256 public stablecoinDecimals;
    address public kernel;
    IPHO public pho;
    mapping(address => uint256) public issuedAmount;

    modifier onlyModuleManager() {
        require(msg.sender == address(moduleManager), "Only ModuleManager");
        _;
    }

    /// Constructor
    constructor(address _moduleManager, address _stablecoin, address _kernel, address _pho) {
        if (
            _moduleManager == address(0) || _stablecoin == address(0) || _kernel == address(0)
                || _pho == address(0)
        ) {
            revert ZeroAddressDetected();
        }
        moduleManager = IModuleManager(_moduleManager);
        stablecoin = IERC20Metadata(_stablecoin);
        stablecoinDecimals = stablecoin.decimals();
        if (stablecoinDecimals > 18) {
            revert OverEighteenDecimals();
        }
        kernel = _kernel;
        pho = IPHO(_pho);
    }

    /// @notice user deposits their stablecoin
    /// @param depositAmount deposit amount (in stablecoin decimals)
    function depositStablecoin(uint256 depositAmount) external nonReentrant {
        // scale if decimals < 18
        uint256 scaledDepositAmount = depositAmount;
        scaledDepositAmount = depositAmount * (10 ** (18 - stablecoinDecimals));

        // transfer stablecoin from caller
        stablecoin.safeTransferFrom(msg.sender, address(this), depositAmount);

        issuedAmount[msg.sender] += scaledDepositAmount;

        // mint PHO
        moduleManager.mintPHO(msg.sender, scaledDepositAmount);

        emit StablecoinDeposited(msg.sender, depositAmount);
    }

    /// @notice user redeems PHO for their original stablecoin
    /// @param redeemAmount redeem amount in terms of PHO, which is 18 decimals
    function redeemStablecoin(uint256 redeemAmount) external nonReentrant {
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

        emit PHORedeemed(msg.sender, redeemAmount);
    }
}
