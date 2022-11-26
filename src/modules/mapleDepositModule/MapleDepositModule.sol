// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@protocol/interfaces/IPHO.sol";
import "@protocol/interfaces/IModuleManager.sol";
import "@oracle/ChainlinkPriceFeed.sol";
import "./IMplRewards.sol";
import "./IPool.sol";
import "../interfaces/IModuleAMO.sol";
import "./MapleModuleAMO.sol";

/// @title MapleDepositModule
/// @author Ekonomia: https://github.com/ekonomia-tech
/// @notice Accepts deposit token for use in Maple lending pool
contract MapleDepositModule is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// Errors
    error ZeroAddressDetected();
    error OverEighteenDecimals();
    error DepositTokenMustBeMaplePoolAsset();
    error MaplePoolNotOpen();
    error CannotRedeemZeroTokens();
    error OnlyModuleManager();
    error CannotDepositZero();

    /// State vars
    IModuleManager public moduleManager;
    address public kernel;
    address public depositToken;
    uint8 public depositTokenDecimals;
    IPHO public pho;
    ChainlinkPriceFeed public oracle;
    IPool public mplPool;
    address public mapleModuleAMO;
    mapping(address => uint256) public issuedAmount; // PHO issued

    address rewardToken = 0x33349B282065b0284d756F0577FB39c158F935e6; // MPL

    /// Events
    event Deposited(address indexed depositor, uint256 depositAmount, uint256 phoMinted);
    event Redeemed(address indexed redeemer, uint256 redeemAmount);
    event MapleRewardsReceived(uint256 totalRewards);
    event Withdrawn(address to, uint256 amount);

    modifier onlyModuleManager() {
        if (msg.sender != address(moduleManager)) {
            revert OnlyModuleManager();
        }
        _;
    }

    /// Constructor
    constructor(
        address _moduleManager,
        address _kernel,
        address _pho,
        address _oracle,
        address _depositToken,
        address _mplStakingAMO,
        address _mplPool
    ) {
        if (
            _moduleManager == address(0) || _kernel == address(0) || _pho == address(0)
                || _oracle == address(0) || _depositToken == address(0) || _mplStakingAMO == address(0)
                || _mplPool == address(0)
        ) {
            revert ZeroAddressDetected();
        }
        moduleManager = IModuleManager(_moduleManager);
        kernel = _kernel;
        pho = IPHO(_pho);
        oracle = ChainlinkPriceFeed(_oracle);
        depositToken = _depositToken;
        depositTokenDecimals = IERC20Metadata(depositToken).decimals();
        if (depositTokenDecimals > 18) {
            revert OverEighteenDecimals();
        }
        mplPool = IPool(_mplPool);
        if (mplPool.liquidityAsset() != _depositToken) {
            revert DepositTokenMustBeMaplePoolAsset();
        }
        if (!mplPool.openToPublic()) {
            revert MaplePoolNotOpen();
        }

        MapleModuleAMO mapleModuleAMOInstance = new MapleModuleAMO(
            "Photon Maple AMO",
            "MPLAMO",
            0x6F6c8013f639979C84b756C7FC1500eB5aF18Dc4, // MPL-LP
            rewardToken,
            msg.sender,
            address(this),
            _depositToken,
            _mplStakingAMO,
            _mplPool
        );

        mapleModuleAMO = address(mapleModuleAMOInstance);
    }

    /// @notice Deposit into underlying MPL pool and rewards
    /// @param depositAmount Deposit amount (in depositToken decimals)
    function deposit(uint256 depositAmount) external nonReentrant {
        if (depositAmount == 0) {
            revert CannotDepositZero();
        }
        // Adjust based on oracle price
        uint256 phoMinted = depositAmount * (10 ** (18 - depositTokenDecimals));
        phoMinted = (phoMinted * oracle.getPrice(depositToken)) / 10 ** 18;

        //depositedAmount[msg.sender] += depositAmount;
        issuedAmount[msg.sender] += phoMinted;

        // Mints PHO
        moduleManager.mintPHO(msg.sender, phoMinted);

        // Call AMO
        IModuleAMO(mapleModuleAMO).stakeFor(msg.sender, depositAmount);

        emit Deposited(msg.sender, depositAmount, phoMinted);
    }

    /// @notice User redeems PHO for their original tokens
    function redeem() public nonReentrant {
        uint256 redeemAmount = issuedAmount[msg.sender];
        if (redeemAmount == 0) {
            revert CannotRedeemZeroTokens();
        }

        issuedAmount[msg.sender] -= redeemAmount;

        // Burn PHO
        moduleManager.burnPHO(msg.sender, redeemAmount);

        // Note: Always a full withdrawal
        IModuleAMO(mapleModuleAMO).withdrawAllFor(msg.sender);
        emit Redeemed(msg.sender, redeemAmount);
    }
}
