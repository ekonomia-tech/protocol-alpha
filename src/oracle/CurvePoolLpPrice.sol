// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ICurvePool} from "@external/curve/ICurvePool.sol";
import {IPriceOracle} from "@oracle/IPriceOracle.sol";

import {Decimal18, decimal18} from "../libraries/Decimal18.sol";

abstract contract CurvePoolLpPrice {
    using Decimal18 for uint256;
    using Decimal18 for decimal18;

    ICurvePool public immutable fraxBPPool; // frax basepool (USDC && Frax underlying assets) used for normalizing FraxBP price to USD with priceFeeds
    IERC20 public immutable fraxBPLP; // fraxBP LP Token address
    IPriceOracle public immutable priceFeeds;
    address public immutable fraxAddress;
    address public immutable usdcAddress;

    constructor(
        ICurvePool _fraxBPPool,
        IERC20 _fraxBPLP,
        IPriceOracle _priceFeeds,
        address _fraxAddress,
        address _usdcAddress
    ) {
        fraxBPPool = _fraxBPPool;
        fraxBPLP = _fraxBPLP;
        priceFeeds = _priceFeeds;
        fraxAddress = _fraxAddress;
        usdcAddress = _usdcAddress;
    }

    /// @notice helper to get USD per FraxBP by checking underlying asset composition (FRAX and USDC)
    /// @return newest USD/FraxBP (normalized by d18) price answer derived from fraxBP balances and USD/Frax && USD/USDC priceFeeds
    function _getUSDPerFraxBP() internal view returns (uint256) {
        // fetching token amounts in the FraxBP pool
        decimal18 fraxBalance = fraxBPPool.balances(0).toDecimal18();
        decimal18 usdcBalance = fraxBPPool.balances(1).toDecimal18({decimals: 6});

        // chainlink prices of the tokens in FraxBP pool
        decimal18 fraxPrice = priceFeeds.getPrice(fraxAddress).toDecimal18();
        decimal18 usdcPrice = priceFeeds.getPrice(usdcAddress).toDecimal18();

        // calculate total value in the pool and
        decimal18 poolTvlInUsd = fraxBalance.mul(fraxPrice).add(usdcBalance.mul(usdcPrice));
        return poolTvlInUsd.div(fraxBPLP.totalSupply().toDecimal18()).toUint256();
    }
}
