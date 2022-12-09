// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "@oracle/IPriceOracle.sol";
import {IWSTETH} from "@modules/interfaces/ERC20AddOns.sol";

contract wstETHOracle is IPriceOracle {
    error ZeroAddress();

    IWSTETH public wstETH = IWSTETH(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    IPriceOracle public priceOracle;

    address private constant STETH_ADDRESS = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    uint256 private constant PRICE_PRECISION = 10 ** 18;

    constructor(address _priceOracle) {
        if (_priceOracle == address(0)) revert ZeroAddress();
        priceOracle = IPriceOracle(_priceOracle);
    }

    /// @notice gets the price of wstETH in USD
    function getPrice(address) public view returns (uint256) {
        uint256 stETHPrice = _getStETHPrice();
        uint256 stEthPerToken = wstETH.stEthPerToken();
        return stETHPrice * stEthPerToken / PRICE_PRECISION;
    }

    /// @notice get the stETH price in USD
    function _getStETHPrice() private view returns (uint256) {
        return priceOracle.getPrice(STETH_ADDRESS);
    }
}
