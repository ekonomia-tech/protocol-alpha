/// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "@modules/interfaces/IModuleAMO.sol";
import "@modules/cdpModule/ICDPPool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title CDP_AMO_stETH.sol
/// @notice AMO for stETH based CDP pool
/// @author Ekonomia

contract CDP_AMO_stETH is IModuleAMO {
    error ZeroAddress();
    error ZeroValue();

    event Staked(address account, uint256 amount);
    event Withdrawn(address account, uint256 amount);
    event RewardsPaid(address account, uint256 amount);

    ICDPPool public pool;
    IERC20 public lido = IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);

    uint256 public accruedRewards;
    uint256 private constant SHARE_PRECISION = 10 ** 18;
    uint256 private constant EMISSIONS_PRECISION = 10 ** 18;
    uint256 private constant EMISSION_RATE = 5 * EMISSIONS_PRECISION / 365 / 1 days;

    mapping(address => uint256) private _balances;
    mapping(address => uint256) private _rewards;
    mapping(address => uint256) private _lastRewardsUpdate;

    modifier updateRewards(address account) {
        uint256 currentRewards =
            lido.balanceOf(address(pool)) - pool.getCollateralBalance() - pool.getFeesCollected();
        if (currentRewards != accruedRewards) {
            accruedRewards = currentRewards;

            uint256 lastRewardsUpdate = _lastRewardsUpdate[account];
            if (lastRewardsUpdate == 0) {
                _lastRewardsUpdate[account] = block.timestamp;
            } else {
                uint256 lastUpdateDelta = block.timestamp - lastRewardsUpdate;
                _rewards[account] =
                    (accruedRewards * EMISSION_RATE / EMISSIONS_PRECISION) * lastUpdateDelta;
                _lastRewardsUpdate[account] = block.timestamp;
            }
        }
        _;
    }

    constructor(address _cdpPool) {
        if (_cdpPool == address(0)) revert ZeroAddress();
        pool = ICDPPool(_cdpPool);
    }

    // Creates tracking shares for user and does external calls as needed
    function stakeFor(address account, uint256 amount)
        external
        updateRewards(account)
        returns (bool)
    {
        if (account == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroValue();

        _balances[account] += amount;

        emit Staked(account, amount);

        return true;
    }

    // Withdraw amount for user
    function withdrawFor(address account, uint256 amount) external updateRewards(account) {
        if (account == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroValue();

        _balances[account] -= amount;

        emit Withdrawn(account, amount);
    }

    // Withdraw all for user
    function withdrawAllFor(address account) external updateRewards(account) {
        if (account == address(0)) revert ZeroAddress();

        uint256 accountBalance = _balances[account];
        _balances[account] -= 0;

        emit Withdrawn(account, accountBalance);
    }

    // Get reward
    function getReward(address account) external updateRewards(account) returns (bool) {
        if (account == address(0)) revert ZeroAddress();

        uint256 userRewards = _rewards[account];
        accruedRewards -= userRewards;

        lido.transferFrom(address(pool), account, userRewards);

        emit RewardsPaid(account, userRewards);

        return true;
    }

    // Queue new _rewards
    function queueNewRewards(uint256 rewards) external returns (bool) {}

    // Staking token
    function stakingToken() external view returns (address) {
        return address(lido);
    }

    // Reward token
    function rewardToken() external view returns (address) {
        return address(lido);
    }

    // Tracks earned amount per user
    function earned(address account) external view returns (uint256) {
        return _rewards[account];
    }
}
