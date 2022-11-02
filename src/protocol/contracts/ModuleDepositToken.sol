// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../interfaces/IModuleTokenMinter.sol";
import "../interfaces/IModule.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title ModuleDepositToken
/// @notice Tracker deposit token for modules
/// @author Ekonomia: https://github.com/Ekonomia
contract ModuleDepositToken is ERC20, IModuleTokenMinter {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address public operator;
    address public depositToken;
    address public module;

    /// Constructor
    /// TODO - module name?
    constructor(address _operator, address _depositToken, address _module)
        ERC20(
            string(abi.encodePacked(ERC20(_depositToken).name(), IModule(_module).name(), " Deposit")),
            string(abi.encodePacked("MOD", ERC20(_depositToken).symbol()))
        )
    {
        operator = _operator;
        depositToken = _depositToken;
        module = _module;
    }

    /// @notice Mint deposit token
    /// @param _to To address
    /// @param _amount Amount
    function mint(address _to, uint256 _amount) external {
        require(msg.sender == operator, "!authorized");
        _mint(_to, _amount);
    }

    /// @notice  Burn deposit token
    /// @param _from From address
    /// @param _amount Amount
    function burn(address _from, uint256 _amount) external {
        require(msg.sender == operator, "!authorized");
        _burn(_from, _amount);
    }
}
