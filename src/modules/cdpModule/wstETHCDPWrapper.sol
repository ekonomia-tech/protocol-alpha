/// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "@modules/cdpModule/ICDPPool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@modules/interfaces/ERC20AddOns.sol";

contract wstETHCDPWrapper {
    error NotETHVariant();

    ICDPPool public pool;
    ISTETH public STETH = ISTETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    IWSTETH public WSTETH = IWSTETH(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    IWETH public WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    modifier onlyETHVariants(address _depositToken) {
        if (
            _depositToken == address(STETH) || _depositToken == address(WSTETH)
                || _depositToken == address(WETH) || (msg.value != 0 && _depositToken == address(0))
        ) {
            _;
        } else {
            revert NotETHVariant();
        }
    }

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
        onlyETHVariants(_depositToken)
    {
        address depositor = address(this);
        uint256 wstETHAmount = _depositAmount;
        if (_depositToken != address(WSTETH)) {
            wstETHAmount = _wrap(_depositAmount, _depositToken);
        } else {
            depositor = msg.sender;
        }
        pool.openFor(depositor, msg.sender, wstETHAmount, _debtAmount);
    }

    /// @notice takes in a collateral in a form of ETH/wETH/stETH/wstETH, automatically converts it to wstETH if needed and add collateral to a position
    /// @param _depositAmount the collateral amount to deposit
    /// @param _depositToken the address of the token submitted. if ETH submitted, address will be address(0)
    function addCollateral(uint256 _depositAmount, address _depositToken)
        external
        payable
        onlyETHVariants(_depositToken)
    {
        address depositor = address(this);
        uint256 wstETHAmount = _depositAmount;
        if (_depositToken != address(WSTETH)) {
            wstETHAmount = _wrap(_depositAmount, _depositToken);
        } else {
            depositor = msg.sender;
        }
        pool.addCollateralFor(depositor, msg.sender, wstETHAmount);
    }

    function _wrap(uint256 _amount, address _depositToken) private returns (uint256) {
        if(_depositToken == address(WETH)) {
            return _processWETH(_amount);
        } else if (_depositToken == address(STETH)) {
            return _processSTETH(_amount);
        }
        return _processETH(_amount);
    }

    function _processWETH(uint256 _amount) private returns (uint256) {
        uint256 ethBalanceBefore = address(this).balance;
        WETH.transferFrom(msg.sender, address(this), _amount);
        WETH.withdraw(_amount);
        uint256 ethBalanceAfter = address(this).balance;
        _amount = ethBalanceAfter - ethBalanceBefore;
        return _processETH(_amount);
    }

    function _processETH(uint256 _amount) private returns (uint256){
        uint256 balBefore = WSTETH.balanceOf(address(this));
        address(WSTETH).call{value: _amount}("");
        uint256 balAfter = WSTETH.balanceOf(address(this));
        return balAfter - balBefore;
    }

    function _processSTETH(uint256 _amount) private returns (uint256) {
        uint256 balBefore = WSTETH.balanceOf(address(this));
        STETH.transferFrom(msg.sender, address(this), _amount);
        WSTETH.wrap(_amount);
        uint256 balAfter = WSTETH.balanceOf(address(this));
        return balAfter - balBefore;
    }
}
