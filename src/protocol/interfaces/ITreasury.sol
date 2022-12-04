pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IKernel {
    event WithdrawTo(address indexed user, uint256 amount);

    function setOperator(address _op) external;
    function withdrawTo(IERC20 _asset, uint256 _amount, address _to) external;
    function execute(address _to, uint256 _value, bytes calldata _data)
        external
        returns (bool, bytes memory);
}
