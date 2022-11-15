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
    error ZeroDeposited();

    event Staked(address account, uint256 amount, uint256 shares);
    event Withdrawn(address account, uint256 amount);
    event RewardsPaid(address account, uint256 amount);

    ICDPPool public pool;
    IERC20 public lido = IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);

    uint256 private _totalShares;
    /// simulates totalSupply() as if LP tokens are used
    uint256 private _totalBalance;
    /// total balance of the pool including rewards
    mapping(address => uint256) private _deposits;
    /// user balances used in this AMO
    mapping(address => uint256) private _shares;
    /// shares are used to simulate LP tokens

    constructor(address _pool) {
        if (_pool == address(0)) revert ZeroAddress();
        pool = ICDPPool(_pool);
    }

    // Creates tracking shares for user and does external calls as needed
    function stakeFor(address account, uint256 amount) external returns (bool) {
        if (account == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroValue();

        updateBalance();

        uint256 shares = _toShares(amount);
        _deposits[account] += amount;
        _shares[account] += shares;
        _totalShares += shares;

        emit Staked(account, amount, shares);

        return true;
    }

    // Withdraw amount for user
    function withdrawFor(address account, uint256 amount) external {
        if (account == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroValue();

        updateBalance();

        uint256 currentShares = _shares[account];
        uint256 currentDeposit = _toAmount(currentShares);
        _deposits[account] -= amount;
        _totalBalance -= amount;
        uint256 newShares = _toShares(currentDeposit - amount);
        _shares[account] = newShares;
        _totalShares = _totalShares - currentShares + newShares;

        emit Withdrawn(account, amount);
    }

    // Withdraw all for user
    function withdrawAllFor(address account) external {
        if (account == address(0)) revert ZeroAddress();
        uint256 deposit = _deposits[account];

        if (deposit == 0) revert ZeroDeposited();

        updateBalance();

        uint256 rewards = earned(account);
        uint256 shares = _shares[account];
        _totalBalance -= deposit;
        _totalShares -= shares;
        delete _deposits[account];
        delete _shares[account];

        lido.transferFrom(address(pool), account, rewards);

        emit RewardsPaid(account, rewards);
        emit Withdrawn(account, deposit);
    }

    // Staking token
    function stakingToken() external view returns (address) {
        return address(lido);
    }

    // Reward token
    function rewardToken() external view returns (address) {
        return address(lido);
    }

    // Tracks earned amount per user
    function earned(address account) public view returns (uint256) {
        if (account == address(0)) revert ZeroAddress();
        return _toAmount(_shares[account]) - _deposits[account];
    }

    function _toShares(uint256 amount) private view returns (uint256) {
        if (_totalShares == 0) {
            return amount;
        }
        return amount * _totalShares / _totalBalance;
    }

    function _toAmount(uint256 shares) private view returns (uint256) {
        return shares * _totalBalance / _totalShares;
    }

    function updateBalance() public {
        uint256 current = lido.balanceOf(address(pool));
        if (current != _totalBalance) {
            _totalBalance = current;
        }
    }
}
