// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../interfaces/IModuleAMO.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IMplRewards.sol";
import "./IPool.sol";

/// @title MapleModuleAMO
/// @notice Maple Module AMO, inspired by Synthetix
/// @author Ekonomia: https://github.com/Ekonomia
contract MapleModuleAMO is IModuleAMO {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Errors
    error CannotReceiveZeroMPT();
    error ZeroAddressDetected();
    error CannotStakeZero();

    /// State vars
    address public rewardToken;
    address public stakingToken;
    uint256 public constant duration = 7 days;

    address public operator;
    address public module;

    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public queuedRewards = 0;
    uint256 public currentRewards = 0;
    uint256 public historicalRewards = 0;
    uint256 public constant newRewardRatio = 830;
    uint256 private _totalSupply;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) private _balances;

    // Other state vars
    mapping(address => uint256) public depositedAmount; // MPL deposited
    mapping(address => uint256) public stakedAmount; // MPL staked

    // Needed for interactions w/ external contracts
    address public depositToken;
    IMplRewards public mplRewards;
    IPool public mplPool;

    // Events
    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event MapleRewardsReceived(uint256 totalRewards);

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    modifier onlyOperator() {
        require(msg.sender == address(operator), "Only Operator");
        _;
    }

    modifier onlyModule() {
        require(msg.sender == address(module), "Only Module");
        _;
    }

    /// Constructor
    constructor(
        address _stakingToken,
        address _rewardToken,
        address _operator,
        address _module,
        address _depositToken,
        address _mplRewards,
        address _mplPool
    ) {
        if (
            _stakingToken == address(0) || _rewardToken == address(0) || _operator == address(0)
                || _module == address(0) || _depositToken == address(0) || _mplRewards == address(0)
                || _mplPool == address(0)
        ) {
            revert ZeroAddressDetected();
        }
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        operator = _operator;
        module = _module;
        mplRewards = IMplRewards(_mplRewards);
        mplPool = IPool(_mplPool);

        depositToken = _depositToken;

        // Approve deposit token for mplPool
        IERC20(depositToken).safeIncreaseAllowance(address(mplPool), type(uint256).max);
    }

    /// Total supply
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /// Balance of
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    /// @notice Get latest timestamp applicable for reward
    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    /// @notice Get reward per token
    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored.add(
            lastTimeRewardApplicable().sub(lastUpdateTime).mul(rewardRate).mul(1e18).div(
                totalSupply()
            )
        );
    }

    /// @notice Get earned amount by account
    /// @param account Account
    function earned(address account) public view returns (uint256) {
        return balanceOf(account).mul(rewardPerToken().sub(userRewardPerTokenPaid[account])).div(
            1e18
        ).add(rewards[account]);
    }

    /// @notice Stake for
    /// @param account For
    /// @param amount Amount
    function stakeFor(address account, uint256 amount)
        public
        updateReward(account)
        returns (bool)
    {
        if (amount == 0) {
            revert CannotStakeZero();
        }

        uint256 mplBalanceBeforeDeposit = mplPool.balanceOf(address(this));
        mplPool.deposit(amount);

        // Pool tokens received
        uint256 mplPoolTokensReceived = mplPool.balanceOf(address(this)) - mplBalanceBeforeDeposit;

        if (mplPoolTokensReceived == 0) {
            revert CannotReceiveZeroMPT();
        }

        // Approve pool tokens for mplStakingAMO
        mplPool.increaseCustodyAllowance(address(mplRewards), mplPoolTokensReceived);

        // Stakes deposit token in mplStakingAMO
        mplRewards.stake(mplPoolTokensReceived);

        depositedAmount[account] += amount;
        stakedAmount[account] += mplPoolTokensReceived;

        _totalSupply = _totalSupply.add(mplPoolTokensReceived);
        _balances[account] = _balances[account].add(mplPoolTokensReceived);

        emit Staked(account, mplPoolTokensReceived);

        return true;
    }

    /// @notice Intend to withdraw
    function intendToWithdraw() external onlyOperator {
        mplPool.intendToWithdraw();
    }

    /// @notice Withdraw
    /// @param account Account
    /// @param amount amount
    function withdrawFor(address account, uint256 amount) public onlyModule updateReward(account) {
        uint256 depositAmount = depositedAmount[account];
        uint256 stakedPoolTokenAmount = stakedAmount[account];
        depositedAmount[account] -= depositAmount;
        stakedAmount[account] -= stakedPoolTokenAmount;

        // Withdraw from rewards
        mplRewards.withdraw(stakedPoolTokenAmount);

        // Withdraw from pool
        mplPool.withdraw(depositAmount);

        // Transfer depositToken to caller
        IERC20(depositToken).transfer(account, depositAmount);

        emit Withdrawn(account, amount);
    }

    /// @notice Withdraw all for
    /// @param account Account
    function withdrawAllFor(address account) external {
        withdrawFor(account, _balances[account]);
    }

    /// @notice gets reward from maple pool
    function getRewardMaple() external onlyOperator returns (uint256) {
        // Get rewards from MPL staking contract
        mplRewards.getReward();
        uint256 totalRewards = IERC20(rewardToken).balanceOf(address(this));
        emit MapleRewardsReceived(totalRewards);
        return totalRewards;
    }

    /// @notice Get reward
    /// @param account Account
    function getReward(address account) public updateReward(account) returns (bool) {
        uint256 reward = earned(account);
        if (reward > 0) {
            rewards[account] = 0;
            IERC20(rewardToken).safeTransfer(account, reward);
            emit RewardPaid(account, reward);
        }
        return true;
    }

    /// @notice Get reward for msg.sender
    function getReward() external returns (bool) {
        getReward(msg.sender);
        return true;
    }

    /// @notice Queue new rewards
    /// @param _rewards Rewards
    function queueNewRewards(uint256 _rewards) external onlyOperator returns (bool) {
        _rewards = _rewards.add(queuedRewards);

        if (block.timestamp >= periodFinish) {
            historicalRewards = historicalRewards.add(_rewards);
            if (block.timestamp >= periodFinish) {
                rewardRate = _rewards.div(duration);
            } else {
                uint256 remaining = periodFinish.sub(block.timestamp);
                uint256 leftover = remaining.mul(rewardRate);
                _rewards = _rewards.add(leftover);
                rewardRate = _rewards.div(duration);
            }
            currentRewards = _rewards;
            lastUpdateTime = block.timestamp;
            periodFinish = block.timestamp.add(duration);
            emit RewardAdded(_rewards);
            queuedRewards = 0;
            return true;
        }

        //et = now - (finish-duration)
        uint256 elapsedTime = block.timestamp.sub(periodFinish.sub(duration));
        //current at now: rewardRate * elapsedTime
        uint256 currentAtNow = rewardRate * elapsedTime;
        uint256 queuedRatio = currentAtNow.mul(1000).div(_rewards);

        //uint256 queuedRatio = currentRewards.mul(1000).div(_rewards);
        if (queuedRatio < newRewardRatio) {
            historicalRewards = historicalRewards.add(_rewards);
            if (block.timestamp >= periodFinish) {
                rewardRate = _rewards.div(duration);
            } else {
                uint256 remaining = periodFinish.sub(block.timestamp);
                uint256 leftover = remaining.mul(rewardRate);
                _rewards = _rewards.add(leftover);
                rewardRate = _rewards.div(duration);
            }
            currentRewards = _rewards;
            lastUpdateTime = block.timestamp;
            periodFinish = block.timestamp.add(duration);
            emit RewardAdded(_rewards);
            queuedRewards = 0;
        } else {
            queuedRewards = _rewards;
        }
        return true;
    }
}
