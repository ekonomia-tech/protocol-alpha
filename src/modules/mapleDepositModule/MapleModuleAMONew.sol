// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../interfaces/IModuleAMO.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IMplRewards.sol";
import "./IPool.sol";

/// @title MapleModuleAMO New version
/// @notice Maple Module AMO
/// @author Ekonomia: https://github.com/Ekonomia
contract MapleModuleAMONew is IModuleAMO, ERC20 {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Errors
    error CannotReceiveZeroMPT();
    error ZeroAddressDetected();
    error CannotStakeZero();

    /// State vars
    address public rewardToken;
    address public stakingToken;
    address public operator;
    address public module;
    uint256 private _totalSupply;
    mapping(address => uint256) public claimedRewards;
    mapping(address => uint256) private _balances;

    // Other state vars
    mapping(address => uint256) public depositedAmount; // MPL deposited
    mapping(address => uint256) public stakedAmount; // MPL staked

    // Tracking vars
    mapping(address => uint256) private _shares;
    uint256 private _totalDeposits;
    uint256 private _totalShares;
    uint256 private _totalRewards;

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
        string memory _name,
        string memory _symbol,
        address _stakingToken,
        address _rewardToken,
        address _operator,
        address _module,
        address _depositToken,
        address _mplRewards,
        address _mplPool
    ) ERC20(_name, _symbol) {
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

    /// @notice Get earned amount by account (total available - claimed)
    /// @param account Account
    function earned(address account) public view returns (uint256) {
        uint256 earnedRewards =
            (balanceOf(account) * _totalRewards) / totalSupply() - claimedRewards[account];
        return earnedRewards;
    }

    /// @notice Convert a deposit/withdraw amount into shares
    function _toShares(uint256 amount) private view returns (uint256) {
        if (_totalShares == 0) {
            return amount;
        }
        return (amount * _totalShares) / _totalDeposits;
    }

    /// @notice Tracks shares for deposits
    function _trackDepositShares(address account, uint256 amount) private returns (uint256) {
        uint256 shares = _toShares(amount);
        _shares[account] += shares;
        _totalShares += shares;
        _mint(account, shares);
        return shares;
    }

    /// @notice Tracks shares for withdrawals
    function _trackWithdrawShares(address account, uint256 amount) private returns (uint256) {
        uint256 shares = _toShares(amount);
        _shares[account] -= shares;
        _totalShares -= shares;
        _burn(account, shares);
        return shares;
    }

    /// @notice Stake for
    /// @param account For
    /// @param amount Amount
    function stakeFor(address account, uint256 amount) public returns (bool) {
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
        _totalDeposits += amount;

        _totalSupply = _totalSupply.add(mplPoolTokensReceived);
        _balances[account] = _balances[account].add(mplPoolTokensReceived);

        uint256 shares = _trackDepositShares(account, amount);
        emit Staked(account, mplPoolTokensReceived); // TODO: shares
        return true;
    }

    /// @notice Intend to withdraw
    function intendToWithdraw() external onlyOperator {
        mplPool.intendToWithdraw();
    }

    /// @notice Withdraw
    /// @param account Account
    /// @param amount amount
    function withdrawFor(address account, uint256 amount) public onlyModule {
        uint256 depositAmount = depositedAmount[account];
        uint256 stakedPoolTokenAmount = stakedAmount[account];
        depositedAmount[account] -= depositAmount;
        stakedAmount[account] -= stakedPoolTokenAmount;

        // Withdraw from rewards
        mplRewards.withdraw(stakedPoolTokenAmount);

        // Withdraw from pool
        mplPool.withdraw(depositAmount);

        uint256 shares = _trackWithdrawShares(account, depositAmount);
        _totalDeposits -= depositAmount;

        // Transfer depositToken to caller
        IERC20(depositToken).transfer(account, depositAmount);
        emit Withdrawn(account, amount); // TODO: shares
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
        _totalRewards = IERC20(rewardToken).balanceOf(address(this));
        emit MapleRewardsReceived(_totalRewards);
        return _totalRewards;
    }

    /// @notice Get reward
    /// @param account Account
    function getReward(address account) public returns (bool) {
        uint256 reward = earned(account);
        if (reward > 0) {
            claimedRewards[account] += reward;
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

    /// TODO: remove
    function queueNewRewards(uint256 _rewards) external returns (bool) {
        return true; // TODO: remove
    }
}
