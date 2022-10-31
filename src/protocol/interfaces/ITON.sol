// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface ITON is IERC20Metadata {
    event KernelSet(address indexed kernel);

    function mint(address to, uint256 amount) external;
    function setKernel(address newKernel) external;
    function burnFrom(address account, uint256 amount) external;
}
