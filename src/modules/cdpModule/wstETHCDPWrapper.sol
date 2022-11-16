/// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "forge-std/console.sol";
import "@modules/cdpModule/ICDPPool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@modules/interfaces/Generics.sol";

contract wstETHCDPWrapper {
    error NotAuthorized();

    ICDPPool public pool;
    ISTETH public STETH = ISTETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    IWSTETH public WSTETH = IWSTETH(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    IWETH public WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    constructor(address _pool) {
        pool = ICDPPool(_pool);
    }

    receive() external payable {}

    /// @notice takes in a collateral in a form of ETH/wETH/stETH/wstETH, automatically converts it to wstETH if needed and opens a position
    /// @param _depositAmount the collateral amount to deposit
    /// @param _debtAmount the amount of debt to take
    /// @param _depositToken the address of the token submitted. if ETH submitted, address will be address(0)
    function open(uint256 _depositAmount, uint256 _debtAmount, address _depositToken)
        external
        payable
    {
        address depositor = address(this);
        uint256 wstETHAmount = _depositAmount;
        if (_depositToken != address(WSTETH)) {
            wstETHAmount = _processDeposit(msg.sender, _depositAmount, _depositToken, msg.value > 0);
        } else {
            depositor = msg.sender;
        }
        pool.openFor(depositor, msg.sender, wstETHAmount, _debtAmount);
    }

    /// @notice takes in a collateral in a form of ETH/wETH/stETH/wstETH, automatically converts it to wstETH if needed and add collateral to a position
    /// @param _depositAmount the collateral amount to deposit
    /// @param _depositToken the address of the token submitted. if ETH submitted, address will be address(0)
    function addCollateral(uint256 _depositAmount, address _depositToken) external payable {
        address depositor = address(this);
        uint256 wstETHAmount = _depositAmount;
        if (_depositToken != address(WSTETH)) {
            wstETHAmount = _processDeposit(msg.sender, _depositAmount, _depositToken, msg.value > 0);
        } else {
            depositor = msg.sender;
        }
        pool.addCollateralFor(depositor, msg.sender, wstETHAmount);
    }

    /// @notice performing the conversion of ETH/wETH/stETH to wstETH
    /// @param _user the user that deposits the collateral and opens the position
    /// @param _amount the amount to convert
    /// @param _depositToken the address of the token submitted. if ETH submitted, address will be address(0)
    /// @param _isETH a simple signal that ETH was deposited. Derived from a msg.value > 0 check to verify value was present in the message
    /// @return wstETHAmount the amount of wstETH converted
    function _processDeposit(address _user, uint256 _amount, address _depositToken, bool _isETH)
        private
        returns (uint256)
    {
        uint256 wstETHAmount;
        uint256 balBefore = WSTETH.balanceOf(address(this));

        if (_depositToken == address(WETH)) {
            uint256 ethBalanceBefore = address(this).balance;
            WETH.transferFrom(_user, address(this), _amount);
            WETH.withdraw(_amount);
            uint256 ethBalanceAfter = address(this).balance;
            _amount = ethBalanceAfter - ethBalanceBefore;
            _isETH = true;
        }

        if (_isETH) {
            address(WSTETH).call{value: _amount}("");
        } else {
            STETH.transferFrom(_user, address(this), _amount);
            WSTETH.wrap(_amount);
        }

        uint256 balAfter = WSTETH.balanceOf(address(this));
        wstETHAmount = balAfter - balBefore;
        return wstETHAmount;
    }
}
