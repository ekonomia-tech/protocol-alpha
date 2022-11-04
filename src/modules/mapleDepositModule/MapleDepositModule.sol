// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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
import "../interfaces/IModuleRewardPool.sol";
import "../interfaces/IStakingAMO.sol";
import "../interfaces/IModule.sol";
import "../interfaces/IModuleTokenMinter.sol";
import "../common/ModuleDepositToken.sol";
import "../common/ModuleRewardPool.sol";

/// @title MapleDepositModule
/// @author Ekonomia: https://github.com/ekonomia-tech
/// @notice Accepts deposit token for use in Maple lending pool
contract MapleDepositModule is Ownable, ReentrancyGuard, IModule {
    using SafeERC20 for IERC20;

    /// Errors
    error ZeroAddressDetected();
    error OverEighteenDecimals();
    error DepositTokenMustBeMaplePoolAsset();
    error MaplePoolNotOpen();
    error CannotReceiveZeroMPT();
    error CannotRedeemZeroTokens();

    /// State vars
    IModuleManager public moduleManager;
    address public kernel;
    address public depositToken;
    uint8 public depositTokenDecimals;
    IPHO public pho;
    ChainlinkPriceFeed public oracle;
    IStakingAMO public mplStakingAMO;
    IPool public mplPool;
    IModuleRewardPool public moduleRewardPool; // TODO; instantiate in tests
    IModuleTokenMinter public moduleDepositToken;
    mapping(address => uint256) public depositedAmount; // MPL deposited
    mapping(address => uint256) public issuedAmount; // PHO issued
    mapping(address => uint256) public stakedAmount; // MPL staked

    address stakingToken = 0x6F6c8013f639979C84b756C7FC1500eB5aF18Dc4; // MPL-LP
    address rewardToken = 0x33349B282065b0284d756F0577FB39c158F935e6; // MPL

    /// Events
    event MapleDeposited(address indexed depositor, uint256 depositAmount, uint256 phoMinted);
    event MapleRedeemed(address indexed redeemer, uint256 redeemAmount);
    event MapleRewardsReceived(uint256 totalRewards);
    event Withdrawn(address to, uint256 amount);

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
        mplStakingAMO = IStakingAMO(_mplStakingAMO);
        mplPool = IPool(_mplPool);
        if (mplPool.liquidityAsset() != _depositToken) {
            revert DepositTokenMustBeMaplePoolAsset();
        }
        if (!mplPool.openToPublic()) {
            revert MaplePoolNotOpen();
        }

        // Approve deposit token for mplPool
        IERC20(depositToken).safeIncreaseAllowance(address(mplPool), type(uint256).max);

        // TODO: make module deposit token (IModuleTokenMinter)
        ModuleDepositToken mToken = new ModuleDepositToken(
            address(this),
            _depositToken,
            address(this)
        );
        moduleDepositToken = IModuleTokenMinter(mToken);

        ModuleRewardPool mRewardPool = new ModuleRewardPool(
            stakingToken,
            rewardToken,
            address(this),
            address(this)
        );
        moduleRewardPool = IModuleRewardPool(address(mRewardPool));
    }

    /// @notice Deposit into underlying MPL pool and rewards
    /// @param depositAmount Deposit amount (in depositToken decimals)
    function deposit(uint256 depositAmount) external nonReentrant {
        // Adjust based on oracle price
        uint256 phoMinted = depositAmount * (10 ** (18 - depositTokenDecimals));
        phoMinted = (phoMinted * oracle.getPrice(depositToken)) / 10 ** 18;

        // transfer depositToken
        IERC20(depositToken).safeTransferFrom(msg.sender, address(this), depositAmount);

        depositedAmount[msg.sender] += depositAmount;
        issuedAmount[msg.sender] += phoMinted;

        // Mints PHO
        moduleManager.mintPHO(msg.sender, phoMinted);

        // Contract transfers to mplPool

        // How many mplPool tokens do we currently own
        uint256 mplBalanceBeforeDeposit = mplPool.balanceOf(address(this));

        // Deposit into mplPool
        mplPool.deposit(depositAmount);

        // Pool tokens received
        uint256 mplPoolTokensReceived = mplPool.balanceOf(address(this)) - mplBalanceBeforeDeposit;

        if (mplPoolTokensReceived == 0) {
            revert CannotReceiveZeroMPT();
        }

        // Approve pool tokens for mplStakingAMO
        mplPool.increaseCustodyAllowance(address(mplStakingAMO), mplPoolTokensReceived);

        // Stakes deposit token in mplStakingAMO
        mplStakingAMO.stake(mplPoolTokensReceived);

        // TODO: mint deposit tracker, token
        // TODO: then call stakeFor() in pool contract

        moduleDepositToken.mint(msg.sender, mplPoolTokensReceived);

        moduleRewardPool.stakeFor(msg.sender, mplPoolTokensReceived);

        stakedAmount[msg.sender] += mplPoolTokensReceived;

        emit MapleDeposited(msg.sender, depositAmount, phoMinted);
    }

    /// @notice Intend to withdraw
    function intendToWithdraw() external onlyOwner {
        mplPool.intendToWithdraw();
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

        // Adjust based on oracle price
        uint256 scaledRedeemAmount = redeemAmount / (10 ** (18 - depositTokenDecimals));
        scaledRedeemAmount = (scaledRedeemAmount * oracle.getPrice(depositToken)) / 10 ** 18;

        uint256 depositAmount = depositedAmount[msg.sender];
        uint256 stakedPoolTokenAmount = stakedAmount[msg.sender];
        depositedAmount[msg.sender] -= depositAmount;
        stakedAmount[msg.sender] -= stakedPoolTokenAmount;

        // Burn module deposit token
        moduleDepositToken.burn(msg.sender, stakedPoolTokenAmount);

        // Withdraw from staking AMO
        mplStakingAMO.withdraw(stakedPoolTokenAmount);

        // Withdraw from pool
        mplPool.withdraw(depositAmount);

        // Transfer depositToken to caller
        IERC20(depositToken).transfer(msg.sender, depositAmount);

        emit MapleRedeemed(msg.sender, redeemAmount);
    }

    /// @notice Gets reward via MplRewards
    /// Currently rewards are in this contract and not withdrawn
    /// TODO: another PR to get rewards distributed to users, and not stuck in contract
    /// Function in MPL rewards contract is called getReward()
    function getRewardMaple() external onlyOwner {
        // Get rewards
        mplStakingAMO.getReward();
        IERC20 rewardToken = IERC20(mplStakingAMO.rewardsToken());
        uint256 totalRewards = rewardToken.balanceOf(address(this));
        emit MapleRewardsReceived(totalRewards);
    }

    /// @notice Claim rewards
    /// @param _address Recipient
    /// @param _amount Amount
    function rewardClaimed(address _address, uint256 _amount) external returns (bool) {
        address rewardContract = address(moduleRewardPool);
        // What is lockRewards?
        require(msg.sender == rewardContract, "!auth");

        //mint reward tokens
        moduleDepositToken.mint(_address, _amount);

        return true;
    }

    // Allow reward contracts to send here and withdraw to user
    function withdrawTo(uint256 _amount, address _to) external returns (bool) {
        address rewardContract = address(moduleRewardPool);
        require(msg.sender == rewardContract, "!auth");

        _withdraw(_amount, msg.sender, _to);
        return true;
    }

    // TODO: edit
    // Helper function for withdraw on module deposit side
    function _withdraw(uint256 _amount, address _from, address _to) internal {
        // Remove moduleDepositToken balance
        moduleDepositToken.burn(_from, _amount);

        redeem();

        //return lp tokens
        IERC20(address(moduleDepositToken)).safeTransfer(_to, _amount);

        emit Withdrawn(_to, _amount);
    }
}
