// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@protocol/interfaces/ITreasury.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Treasury is ITreasury {
    address public tonGovernance;

    modifier onlyTONGovernance() {
        if (msg.sender != tonGovernance) revert Unauthorized();
        _;
    }

    constructor(address _tonGovernance) {
        if (_tonGovernance == address(0)) revert ZeroAddress();
        tonGovernance = _tonGovernance;
    }

    receive() external payable {}

    function withdrawTokens(address to, address asset, uint256 amount) external onlyTONGovernance {
        if (to == address(0) || asset == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroValue();
        IERC20(asset).transfer(to, amount);
        emit Withdrawn(to, asset, amount);
    }

    function execute(address to, uint256 value, bytes calldata data)
        external
        onlyTONGovernance
        returns (bool, bytes memory)
    {
        if (to == address(0)) revert ZeroAddress();
        if (value == 0) revert ZeroValue();
        (bool success, bytes memory result) = to.call{value: value}(data);
        return (success, result);
    }
}
