// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@protocol/interfaces/IPHO.sol";
import "@protocol/interfaces/IModuleManager.sol";
import "@protocol/interfaces/IModuleManager.sol";
import "@oracle/ChainlinkPriceFeed.sol";
import "./IMplRewards.sol";
import "./IPool.sol";

/// @title MapleDepositModule
/// @author Ekonomia: https://github.com/ekonomia-tech
/// @notice Accepts deposit token for use in Maple lending pool
contract MapleDepositModule is Ownable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    /// Errors
    error ZeroAddressDetected();
    error CannotRedeemMoreThanDeposited();
    error OverEighteenDecimals();
    error DepositTokenMustBeMaplePoolAsset();
    error MaplePoolNotOpen();
    error CannotStakeMoreThanDeposited();
    error CannotWithdrawMoreThanStaked();
    error CannotRecieveNoMaplePoolTokens();
    error CannotRedeemZeroTokens();

    /// State vars
    IModuleManager public moduleManager;
    address public kernel;
    IPHO public pho;
    ChainlinkPriceFeed public oracle;
    address public depositToken;
    uint8 public depositTokenDecimals;
    IMplRewards public mplRewards;
    IPool public mplPool;
    mapping(address => uint256) public depositedAmount; // MPL deposited
    mapping(address => uint256) public issuedAmount; // PHO issued
    mapping(address => uint256) public stakedAmount; // MPL staked

    /// Events
    event MapleDeposited(address indexed depositor, uint256 depositAmount, uint256 phoMinted);
    event MapleRedeemed(address indexed redeemer, uint256 redeemAmount);
    event MapleRewardsRecieved(uint256 totalRewards);

    modifier onlyModuleManager() {
        require(msg.sender == address(moduleManager), "Only ModuleManager");
        _;
    }

    /// Constructor
    constructor(
        address _moduleManager,
        address _kernel,
        address _pho,
        address _oracle,
        address _depositToken,
        address _mplRewards,
        address _mplPool
    ) {
        if (
            _moduleManager == address(0) || _kernel == address(0) || _pho == address(0)
                || _oracle == address(0) || _depositToken == address(0) || _mplRewards == address(0)
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
        mplRewards = IMplRewards(_mplRewards);
        mplPool = IPool(_mplPool);
        if (mplPool.liquidityAsset() != _depositToken) {
            revert DepositTokenMustBeMaplePoolAsset();
        }
        if (!mplPool.openToPublic()) {
            revert MaplePoolNotOpen();
        }

        // Approve deposit token for mplPool
        ERC20(depositToken).safeIncreaseAllowance(address(mplPool), type(uint256).max);
    }

    /// @notice Deposit into underlying MPL pool and rewards
    /// @param depositAmount Deposit amount (in mapleToken decimals)
    function depositMaple(uint256 depositAmount) external nonReentrant {
        // Adjust based on oracle price
        uint256 phoMinted = depositAmount * (10 ** (18 - depositTokenDecimals));
        phoMinted = (phoMinted * oracle.getPrice(depositToken)) / 10 ** 18;

        // transfer depositToken
        ERC20(depositToken).safeTransferFrom(msg.sender, address(this), depositAmount);

        depositedAmount[msg.sender] += depositAmount;
        issuedAmount[msg.sender] += phoMinted;

        // Mints PHO
        moduleManager.mintPHO(msg.sender, phoMinted);

        // Contract transfers to mplPool

        // How many mplPool tokens do we currently own
        uint256 mplBalanceBeforeDeposit = mplPool.balanceOf(address(this));

        // Deposit into mplPool
        mplPool.deposit(depositAmount);

        // Pool tokens recieved
        uint256 mplPoolTokensRecieved = mplPool.balanceOf(address(this)) - mplBalanceBeforeDeposit;

        if (mplPoolTokensRecieved == 0) {
            revert CannotRecieveNoMaplePoolTokens();
        }

        // Approve pool tokens for mplRewards
        mplPool.increaseCustodyAllowance(address(mplRewards), mplPoolTokensRecieved);

        // Stakes deposit token in mplRewards
        mplRewards.stake(mplPoolTokensRecieved);

        stakedAmount[msg.sender] += mplPoolTokensRecieved;

        emit MapleDeposited(msg.sender, depositAmount, phoMinted);
    }

    /// @notice Intend to withdraw
    function intendToWithdraw() external onlyOwner {
        mplPool.intendToWithdraw();
    }

    /// @notice User redeems PHO for their original tokens
    function redeemMaple() external nonReentrant {
        uint256 redeemAmount = issuedAmount[msg.sender];
        if (redeemAmount == 0) {
            revert CannotRedeemZeroTokens();
        }

        issuedAmount[msg.sender] -= redeemAmount;

        // Burn PHO
        moduleManager.burnPHO(msg.sender, redeemAmount);

        // Adjust based on oracle price
        uint256 scaledRedeemAmount = redeemAmount / (10 ** (18 - depositTokenDecimals));
        scaledRedeemAmount = (scaledRedeemAmount * oracle.getPrice(depositToken)) / 10 ** 18;

        uint256 depositAmount = depositedAmount[msg.sender];
        uint256 stakedPoolTokenAmount = stakedAmount[msg.sender];
        depositedAmount[msg.sender] -= depositAmount;
        stakedAmount[msg.sender] -= stakedPoolTokenAmount;

        // Withdraw from rewards
        mplRewards.withdraw(stakedPoolTokenAmount);

        // Withdraw from pool
        mplPool.withdraw(depositAmount);

        // Transfer depositToken to caller
        ERC20(depositToken).transfer(msg.sender, depositAmount);

        emit MapleRedeemed(msg.sender, redeemAmount);
    }

    /// @notice Gets reward via MplRewards
    function getRewardMaple() external onlyOwner {
        // Get rewards
        mplRewards.getReward();
        IERC20 rewardToken = IERC20(mplRewards.rewardsToken());
        uint256 totalRewards = rewardToken.balanceOf(address(this));
        emit MapleRewardsRecieved(totalRewards);
    }
}
