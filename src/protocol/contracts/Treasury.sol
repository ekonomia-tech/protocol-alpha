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

    function withdrawETH(address payable to, uint256 amount) external onlyTONGovernance {
        if (amount == 0) revert ZeroValue();
        to.transfer(amount);
    }

}
