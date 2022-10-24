// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
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
    using SafeERC20 for ERC20;

    /// Errors
    error ZeroAddressDetected();
    error CannotRedeemMoreThanDeposited();
    error OverEighteenDecimalPlaces();

    /// State vars
    IModuleManager public moduleManager;
    address public stablecoin;
    uint256 stablecoinDecimals;
    address public kernel;
    IPHO public pho;
    mapping(address => uint256) public issuedAmount;

    /// Events
    event StablecoinWhitelisted(address indexed stablecoin);
    event StablecoinDelisted(address indexed stablecoin);
    event StablecoinDeposited(
        address indexed stablecoin, address indexed depositor, uint256 depositAmount
    );
    event PHORedeemed(address indexed redeemer, uint256 redeemAmount);

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
        stablecoin = _stablecoin;
        stablecoinDecimals = IERC20Metadata(stablecoin).decimals();
        kernel = _kernel;
        pho = IPHO(_pho);
    }

    /// @notice user deposits their stablecoin
    /// @param depositAmount deposit amount (in stablecoin decimals)
    function depositStablecoin(uint256 depositAmount) external nonReentrant {
        if (stablecoinDecimals > 18) {
            revert OverEighteenDecimalPlaces();
        }
        // scale if decimals < 18
        uint256 scaledDepositAmount = depositAmount;

        // note: will fail on overflow when decimals > 18
        scaledDepositAmount = depositAmount * (10 ** (18 - stablecoinDecimals));

        // transfer stablecoin from caller
        ERC20(stablecoin).safeTransferFrom(msg.sender, address(this), depositAmount);

        issuedAmount[msg.sender] += scaledDepositAmount;

        // mint PHO
        moduleManager.mintPHO(msg.sender, scaledDepositAmount);

        emit StablecoinDeposited(address(stablecoin), msg.sender, depositAmount);
    }

    /// @notice user redeems PHO for their original stablecoin
    /// @param redeemAmount redeem amount in terms of PHO, which is 18 decimals
    function redeemStablecoin(uint256 redeemAmount) external nonReentrant {
        if (redeemAmount > issuedAmount[msg.sender]) {
            revert CannotRedeemMoreThanDeposited();
        }
        if (stablecoinDecimals > 18) {
            revert OverEighteenDecimalPlaces();
        }

        issuedAmount[msg.sender] -= redeemAmount;

        // burn PHO
        moduleManager.burnPHO(msg.sender, redeemAmount);

        // scale if decimals < 18
        uint256 scaledRedeemAmount = redeemAmount;
        scaledRedeemAmount = redeemAmount / (10 ** (18 - stablecoinDecimals));

        // transfer stablecoin to caller
        ERC20(stablecoin).transfer(msg.sender, scaledRedeemAmount);

        emit PHORedeemed(msg.sender, redeemAmount);
    }
}
