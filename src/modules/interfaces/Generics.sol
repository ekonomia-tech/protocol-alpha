// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISTETH is IERC20 {
    function submit(address _referral) external payable;
}

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}

interface IWSTETH is IERC20 {
    function wrap(uint256 _stETHAmount) external returns (uint256);
    function unwrap(uint256 _wstETHAmount) external returns (uint256);
    function getWstETHByStETH(uint256 _stETHAmount) external view returns (uint256);
}

interface IUSDC {
    function balanceOf(address account) external view returns (uint256);

    function mint(address to, uint256 amount) external;

    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address to, uint256 amount) external;

    function configureMinter(address minter, uint256 minterAllowedAmount) external;

    function masterMinter() external view returns (address);
}
