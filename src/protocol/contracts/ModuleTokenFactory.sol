// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "./ModuleDepositToken.sol";
import "../interfaces/IModuleTokenFactory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/// @title ModuleTokenFactory
/// @notice Token factory for modules
/// @author Ekonomia: https://github.com/Ekonomia
contract ModuleTokenFactory is IModuleTokenFactory {
    using Address for address;

    address public operator;

    /// Constructor
    constructor(address _operator) public {
        operator = _operator;
    }

    /// @notice Create module deposit token
    /// @param _depositToken deposit token
    function createModuleDepositToken(address _depositToken) external returns (address) {
        require(msg.sender == operator, "!authorized");

        ModuleDepositToken mToken = new ModuleDepositToken(operator, _lptoken);
        return address(mToken);
    }
}
