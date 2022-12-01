// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@protocol/interfaces/ITreasury.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Treasury is ITreasury {
    using SafeERC20 for IERC20;
    using Address for address;

    address public operator;

    event WithdrawTo(address indexed user, uint256 amount);

    modifier onlyOperator() {
        if (msg.sender != operator) {
            revert Unauthorized();
        }
        _;
    }
    constructor(address _operator) public {
        operator = _operator;
    }

    function setOperator(address _op) external onlyOperator {
        operator = _op;
    }

    function withdrawTo(IERC20 _asset, uint256 _amount, address _to) external onlyOperator {
        _asset.safeTransfer(_to, _amount);
        emit WithdrawTo(_to, _amount);
    }

    function execute(address _to, uint256 _value, bytes calldata _data)
        external
        onlyOperator
        returns (bool, bytes memory)
    {
        (bool success, bytes memory result) = _to.call{value: _value}(_data);

        return (success, result);
    }
}
