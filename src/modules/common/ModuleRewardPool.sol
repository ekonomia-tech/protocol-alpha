// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../interfaces/IModuleRewardPool.sol";
import "../interfaces/IModule.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "forge-std/console2.sol";

/// @title ModuleRewardPool
/// @notice Module reward pool, inspired by Synthetix
/// @author Ekonomia: https://github.com/Ekonomia
/// TODO -> replace ModuleDispatcher
/// TODO -> add rewardClaimed() on module side
contract ModuleRewardPool {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public rewardToken;
    address public stakingToken;
    uint256 public constant duration = 7 days;

    address public operator;
    address public rewardManager;

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

    address[] public extraRewards;

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    /// Constructor
    constructor(
        address _stakingToken,
        address _rewardToken,
        address _operator,
        address _rewardManager
    ) public {
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        operator = _operator;
        rewardManager = _rewardManager;
    }

    /// Total supply
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /// Balance of
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    /// Extra rewards length
    function extraRewardsLength() external view returns (uint256) {
        return extraRewards.length;
    }

    /// @notice Add extra reward
    function addExtraReward(address _reward) external {
        require(msg.sender == rewardManager, "!authorized");
        require(_reward != address(0), "!reward setting");
        extraRewards.push(_reward);
        return;
    }

    /// @notice Clear extra rewards
    function clearExtraRewards() external {
        require(msg.sender == rewardManager, "!authorized");
        delete extraRewards;
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
    /// @param _for For
    /// @param _amount Amount
    function stakeFor(address _for, uint256 _amount) public updateReward(_for) returns (bool) {
        require(_amount > 0, "RewardPool : Cannot stake 0");

        //give to _for
        _totalSupply = _totalSupply.add(_amount);
        _balances[_for] = _balances[_for].add(_amount);

        // TODO: call external contract here as needed..
        //take away from sender - TODO: change this?
        // IERC20(stakingToken).safeTransferFrom(
        //     msg.sender,
        //     address(this),
        //     _amount
        // );
        emit Staked(_for, _amount);

        return true;
    }

    /// @notice Withdraw
    /// @param _account Account
    /// @param amount amount
    function withdraw(address _account, uint256 amount) public updateReward(_account) {
        require(msg.sender == address(operator), "Not authorized");
        //require(amount > 0, 'VirtualDepositRewardPool : Cannot withdraw 0');

        emit Withdrawn(_account, amount);
    }

    /// @notice TODO: modify -> withdraw() -> withdrawAmount()
    /// @param amount Amount
    /// @param claim Claim
    function withdrawAmount(uint256 amount, bool claim)
        public
        updateReward(msg.sender)
        returns (bool)
    {
        require(amount > 0, "RewardPool : Cannot withdraw 0");

        // //TODO: modify this also withdraw from linked rewards
        // for (uint256 i = 0; i < extraRewards.length; i++) {
        //     IModuleRewardPool(extraRewards[i]).withdraw(msg.sender, amount);
        // }

        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);

        IERC20(stakingToken).safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);

        if (claim) {
            getReward(msg.sender, true);
        }

        return true;
    }

    /// @notice Withdraw all
    /// @param claim Claim
    function withdrawAll(bool claim) external {
        /// TODO: modify
        //withdraw(_balances[msg.sender], claim);
    }

    /// @notice Withdraw and unwrap
    /// @param amount Amount
    /// @param claim Whether to claim
    function withdrawAndUnwrap(uint256 amount, bool claim)
        public
        updateReward(msg.sender)
        returns (bool)
    {
        //also withdraw from linked rewards
        for (uint256 i = 0; i < extraRewards.length; i++) {
            IModuleRewardPool(extraRewards[i]).withdraw(msg.sender, amount);
        }

        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);

        //tell operator to withdraw from here directly to user
        IModule(operator).withdrawTo(amount, msg.sender);
        emit Withdrawn(msg.sender, amount);

        //get rewards too
        if (claim) {
            getReward(msg.sender, true);
        }
        return true;
    }

    /// @notice Withdraw all and unwrap
    /// @param claim Whether to claim
    function withdrawAllAndUnwrap(bool claim) external {
        withdrawAndUnwrap(_balances[msg.sender], claim);
    }

    /// @notice Get reward
    /// @param _account Account
    /// @param _claimExtras Whether to claim extras
    function getReward(address _account, bool _claimExtras)
        public
        updateReward(_account)
        returns (bool)
    {
        uint256 reward = earned(_account);
        console2.log("ModuleRewardPool -> this is earned: ", reward);
        if (reward > 0) {
            rewards[_account] = 0;
            IERC20(rewardToken).safeTransfer(_account, reward);
            emit RewardPaid(_account, reward);
        }
        return true;
    }

    /// @notice Get reward for msg.sender
    function getReward() external returns (bool) {
        getReward(msg.sender, true);
        return true;
    }

    /// @notice Donates reward token
    /// @param _amount Amount
    function donate(uint256 _amount) external returns (bool) {
        IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), _amount);
        queuedRewards = queuedRewards.add(_amount);
    }

    /// @notice Queue new rewards
    /// @param _rewards Rewards
    function queueNewRewards(uint256 _rewards) external returns (bool) {
        require(msg.sender == operator, "!authorized");

        _rewards = _rewards.add(queuedRewards);

        if (block.timestamp >= periodFinish) {
            notifyRewardAmount(_rewards);
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
            notifyRewardAmount(_rewards);
            queuedRewards = 0;
        } else {
            queuedRewards = _rewards;
        }
        return true;
    }

    /// @notice Notify reward amount
    /// @param reward Reward
    function notifyRewardAmount(uint256 reward) public updateReward(address(0)) {
        historicalRewards = historicalRewards.add(reward);
        if (block.timestamp >= periodFinish) {
            rewardRate = reward.div(duration);
        } else {
            uint256 remaining = periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardRate);
            reward = reward.add(leftover);
            rewardRate = reward.div(duration);
        }
        currentRewards = reward;
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(duration);
        emit RewardAdded(reward);
    }
}
