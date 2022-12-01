// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITreasury {
    error Unauthorized();

    function setOperator(address _op) external;
    function withdrawTo(IERC20 asset, uint256 amount, address to) external;
    function execute(address _to, uint256 _value, bytes calldata _data)
        external
        returns (bool, bytes memory);
}
