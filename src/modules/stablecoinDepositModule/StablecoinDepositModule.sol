// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../../protocol/interfaces/IPHO.sol";
import "../../protocol/interfaces/IModuleManager.sol";

/// @title StablecoinDepositModule
/// @author Ekonomia: https://github.com/ekonomia-tech
/// @notice Accepts specific stablecoin 1:1 i.e. LUSD, DAI, etc.
contract StablecoinDepositModule is Ownable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    /// Errors
    error ZeroAddressDetected();
    error CannotRedeemMoreThanDeposited();

    /// State vars
    IModuleManager public moduleManager;
    address public stablecoin;
    address public kernel;
    IPHO public pho;
    mapping(address => uint256) public issuedAmount;

    /// Events
    event StablecoinWhitelisted(address indexed stablecoin);
    event StablecoinDelisted(address indexed stablecoin);
    event StablecoinDeposited(
        address indexed stablecoin, address indexed depositor, uint256 depositAmount
    );
    event StablecoinRedeemed(
        address indexed stablecoin, address indexed redeemer, uint256 redeemAmount
    );

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
        kernel = _kernel;
        pho = IPHO(_pho);
    }

    /// @notice user deposits their stablecoin
    /// @param depositAmount deposit amount (in stablecoin decimals)
    function depositStablecoin(uint256 depositAmount) external nonReentrant {
        // scale if decimals < 18
        uint256 scaledDepositAmount = depositAmount;
        uint256 stablecoinDecimals = IERC20Metadata(stablecoin).decimals();
        scaledDepositAmount = depositAmount * (10 ** (18 - stablecoinDecimals));

        // transfer stablecoin
        ERC20(stablecoin).safeTransferFrom(msg.sender, address(this), depositAmount);

        issuedAmount[msg.sender] += scaledDepositAmount;

        moduleManager.mintPHO(scaledDepositAmount);
        pho.transfer(msg.sender, scaledDepositAmount);

        emit StablecoinDeposited(address(stablecoin), msg.sender, depositAmount);
    }

    /// @notice user redeems PHO for their original stablecoin
    /// @param redeemAmount redeem amount in terms of PHO - 18 decimals
    function redeemStablecoin(uint256 redeemAmount) external nonReentrant {
        if (redeemAmount > issuedAmount[msg.sender]) {
            revert CannotRedeemMoreThanDeposited();
        }

        issuedAmount[msg.sender] -= redeemAmount;

        // caller gives PHO
        ERC20(address(pho)).safeTransferFrom(msg.sender, address(this), redeemAmount);

        // TODO: burnPho()

        // scale if decimals < 18
        uint256 scaledRedeemAmount = redeemAmount;
        uint256 stablecoinDecimals = IERC20Metadata(stablecoin).decimals();
        scaledRedeemAmount = redeemAmount / (10 ** (18 - stablecoinDecimals));

        // transfer stablecoin to caller
        ERC20(stablecoin).transfer(msg.sender, scaledRedeemAmount);

        emit StablecoinRedeemed(address(stablecoin), msg.sender, redeemAmount);
    }
}
