// Copied from https://etherscan.io/address/0x1389388d01708118b497f59521f6943Be2541bb7
// No Tests written
// Took imports from OZ instead of having the code in this file
// Set compiler to 0.8.13

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

//receive treasury funds. operator can withdraw
//allow execute so that certain funds could be staked etc
//allow treasury ownership to be transferred during the vesting stage
contract TreasuryFunds {
    using SafeERC20 for IERC20;
    using Address for address;

    address public operator;

    event WithdrawTo(address indexed user, uint256 amount);

    constructor(address _operator) {
        operator = _operator;
    }

    function setOperator(address _op) external {
        require(msg.sender == operator, "!auth");
        operator = _op;
    }

    function withdrawTo(IERC20 _asset, uint256 _amount, address _to) external {
        require(msg.sender == operator, "!auth");
        _asset.safeTransfer(_to, _amount);
        emit WithdrawTo(_to, _amount);
    }

    function execute(address _to, uint256 _value, bytes calldata _data)
        external
        returns (bool, bytes memory)
    {
        require(msg.sender == operator, "!auth");
        (bool success, bytes memory result) = _to.call{value: _value}(_data);
        return (success, result);
    }
}
