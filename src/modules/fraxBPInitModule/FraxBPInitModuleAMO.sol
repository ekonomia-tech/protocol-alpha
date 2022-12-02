// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IModuleAMO.sol";
import "./interfaces/IGauge.sol";
import "forge-std/console2.sol";

/// @title FraxBPInitModuleAMO
/// @notice FraxBPInit Module AMO
/// @author Ekonomia: https://github.com/Ekonomia
contract FraxBPInitModuleAMO is IModuleAMO, ERC20 {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Errors
    error ZeroAddressDetected();
    error CannotStakeZero();
    error CannotWithdrawMoreThanDeposited();

    /// State vars
    address public rewardToken;
    address public stakingToken;
    address public operator;
    address public module;
    uint256 private _totalDeposits;
    uint256 private _totalShares;
    uint256 private _totalRewards; // rewards in CRV

    mapping(address => uint256) public depositedAmount; // MPL deposited
    mapping(address => uint256) public stakedAmount; // MPL staked
    mapping(address => uint256) public claimedRewards; // rewards claimed
    mapping(address => uint256) private _shares;

    // Needed for interactions w/ external contracts
    address public depositToken;
    IERC20 public crv = IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52);
    IGauge public curveGauge; // TODO: gauge address

    // Events
    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount, uint256 shares);
    event Withdrawn(address indexed user, uint256 amount, uint256 shares);
    event RewardPaid(address indexed user, uint256 reward);
    event FraxBPInitRewardsReceived(uint256 totalRewards);

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
        address _curveGauge
    ) ERC20(_name, _symbol) {
        if (
            _stakingToken == address(0) || _rewardToken == address(0) || _operator == address(0)
                || _module == address(0) || _depositToken == address(0) || _curveGauge == address(0)
        ) {
            revert ZeroAddressDetected();
        }
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        operator = _operator;
        module = _module;
        depositToken = _depositToken;
        curveGauge = IGauge(_curveGauge);
    }

    /// @notice Get total shares
    function totalShares() public view returns (uint256) {
        return _totalShares;
    }

    /// @notice Get shares of account
    /// @param account Account
    function sharesOf(address account) public view returns (uint256) {
        return _shares[account];
    }

    /// @notice Get earned amount by account (total available - claimed)
    /// @param account Account
    function earned(address account) public view returns (uint256) {
        uint256 ts = totalSupply();
        if (ts == 0) {
            return 0;
        }
        uint256 earnedRewards = (balanceOf(account) * _totalRewards) / ts - claimedRewards[account];
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
    function _trackWithdrawShares(address account) private returns (uint256) {
        uint256 shares = _shares[account];
        _shares[account] = 0;
        _totalShares -= shares;
        _burn(account, shares);
        return shares;
    }

    /// @notice Stake for
    /// @param account For
    /// @param amount Amount
    function stakeFor(address account, uint256 amount) public onlyModule returns (bool) {
        if (amount == 0) {
            revert CannotStakeZero();
        }

        // Get depositToken from module
        IERC20(depositToken).safeTransferFrom(module, address(this), amount);

        // Deposit to gauge
        curveGauge.deposit(amount);

        depositedAmount[account] += amount;
        stakedAmount[account] += amount;
        _totalDeposits += amount;

        uint256 shares = _trackDepositShares(account, amount);
        emit Staked(account, amount, shares);
        return true;
    }

    /// @notice Withdraw
    /// @param account Account
    /// @param amount amount
    function withdrawFor(address account, uint256 amount) public onlyModule returns (bool) {
        uint256 depositAmount = depositedAmount[account];
        uint256 stakedPoolTokenAmount = stakedAmount[account];
        if (amount > depositAmount) {
            revert CannotWithdrawMoreThanDeposited();
        }
        depositedAmount[account] -= depositAmount;
        stakedAmount[account] -= stakedPoolTokenAmount;

        // Withdraw from gauge
        curveGauge.withdraw(amount);

        uint256 shares = _trackWithdrawShares(account);
        _totalDeposits -= depositAmount;

        console2.log(
            "this is in withdrawFor, this is balance of depositToken: ",
            IERC20(depositToken).balanceOf(address(this))
        );

        // Transfer depositToken to caller
        IERC20(depositToken).transfer(account, depositAmount / 2);
        emit Withdrawn(account, amount, shares);
        return true;
    }

    /// @notice Withdraw all for
    /// @param account Account
    function withdrawAllFor(address account) external returns (bool) {
        return withdrawFor(account, depositedAmount[account]);
    }

    /// @notice Gets reward
    function getRewardFraxBPInit() external onlyOperator returns (uint256) {
        uint256 crvBalanceBefore = crv.balanceOf(address(this));
        // Get rewards
        //curveGauge.claim_rewards();
        uint256 crvBalanceAfter = crv.balanceOf(address(this));
        _totalRewards = crvBalanceAfter - crvBalanceBefore;
        emit FraxBPInitRewardsReceived(_totalRewards);
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
}
