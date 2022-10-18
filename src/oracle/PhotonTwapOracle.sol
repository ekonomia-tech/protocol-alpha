// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ICurvePool} from "@external/curve/ICurvePool.sol";
import {IPriceOracle} from "@oracle/IPriceOracle.sol";

import {Decimal18, decimal18} from "../libraries/Decimal18.sol";
import {TimeWeightedAverage} from "../libraries/TimeWeightedAverage.sol";

import {CurvePoolLpPrice} from "./CurvePoolLpPrice.sol";

contract PhotonTwapOracle is Ownable, CurvePoolLpPrice {
    using Decimal18 for uint256;
    using Decimal18 for decimal18;
    using TimeWeightedAverage for TimeWeightedAverage.State;

    ICurvePool public immutable pool;
    int128 public immutable indexOfBase;
    int128 public immutable indexOfQuote;
    bool public immutable nonreentrant;

    uint256 public twapDuration;
    TimeWeightedAverage.State public twa;

    constructor(
        ICurvePool _pool,
        int128 _indexOfBase,
        int128 _indexOfQuote,
        bool _nonreentrant,
        ICurvePool _fraxBPPool,
        IERC20 _fraxBPLP,
        IPriceOracle _priceFeeds,
        address _fraxAddress,
        address _usdcAddress
    ) CurvePoolLpPrice(_fraxBPPool, _fraxBPLP, _priceFeeds, _fraxAddress, _usdcAddress) {
        pool = _pool;
        indexOfBase = _indexOfBase;
        indexOfQuote = _indexOfQuote;
        nonreentrant = _nonreentrant;
    }

    function updateAndGetPrice() external returns (int256) {
        update();
        return getPrice();
    }

    function getPrice() public view returns (int256) {
        return twa.read();
    }

    function update() public {
        int256 spotPrice = _getSpotPrice();

        // do any sanity checks
        // TODO add price threshold, what to do if price is off?
        require(spotPrice > 0);

        twa.update({data: spotPrice, interval: twapDuration});
    }

    function _getSpotPrice() internal view returns (int256) {
        decimal18 fraxBpPerUnitPho = pool.get_dy(indexOfBase, indexOfQuote, 1e18).toDecimal18();
        decimal18 usdPerUnitFraxBp = _getUSDPerFraxBP().toDecimal18(); // TODO see if get_virtual_price can be used instead
        return int256(decimal18.unwrap(fraxBpPerUnitPho.mul(usdPerUnitFraxBp)));
    }
}
