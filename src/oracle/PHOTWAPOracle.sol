// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@protocol/interfaces/IPHO.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@oracle/IPHOOracle.sol";
import "@external/curve/ICurvePool.sol";
import "@oracle/IPriceOracle.sol";

/// @title PHOTWAPOracle
/// @notice Oracle exposing USD/PHO price using v1 Curve PHO/FraxBP Metapool TWAP Pair Oracle && USD PriceFeeds (USD/FRAX && USD/USDC)
/// @author Ekonomia: https://github.com/Ekonomia
/// TODO - Write exhaustive tests ensuring this oracle is robust
/// NOTE - This TWAPOracle is kept simple for security sake. If dealing with new underlying assets and new metapool, create a new PHOTWAPOracle with appropriate new addresses.
contract PHOTWAPOracle is IPHOOracle, Ownable {
    IPHO public pho;
    ICurvePool public dexPool; // curve metapool oracle is pulling balances for twap
    ICurvePool public fraxBPPool; // frax basepool (USDC && Frax underlying assets) used for normalizing FraxBP price to USD with priceFeeds
    IERC20 public fraxBPLP; // fraxBP LP Token address
    IPriceOracle public priceFeeds;

    address public fraxAddress;
    address public usdcAddress;
    uint256 public period; // timespan for regular TWAP updates in seconds
    bool public initOracle; // whether updatePrice() has been called once or not yet
    uint256 public priceCumulativeLast0; // used in calculating twap for both base tokens in dexPool (PHO && FraxBP)
    uint256 public priceCumulativeLast1; // used in calculating twap for both base tokens in dexPool (PHO && FraxBP)
    uint256 public latestBlockTimestamp; // last time updatePrice() was called successfully
    uint256 public latestUSDPHOPrice;

    uint256 public twap0; // index 0 == PHO (units: FraxBP/PHO)
    uint256 public twap1; // index 1 == FraxBP (units: PHO/FraxBP)
    uint256 public priceUpdateThreshold; // expressed in basis points, 10 ** 6 BP corresponding to 100%
    // bool public thresholdExceeded; // See TODO in updatePrice()

    uint256 public constant UPDATEPRICE_THRESHOLD_PRECISION = 10 ** 6;
    uint256 public constant PRICE_PRECISION = 10 ** 18;
    uint256 public constant DECIMALS_DIFFERENCE = 10 ** 12;
    uint256 public constant MAX_PRICE_THRESHOLD = 10 ** 6;

    modifier onlyByOwnerOrGovernance() {
        require(
            msg.sender == owner() || msg.sender == address(this),
            "PHOTWAPOracle: not the owner or timelock"
        );
        _;
    }

    // NOTE - make sure that dex_pool_address has PHO and FraxBP as tokens[0] and tokens[1], respectively
    constructor(
        address _pho_address,
        address _fraxBPPool,
        address _fraxBPLPToken,
        address _fraxAddress,
        address _usdcAddress,
        address _priceFeed,
        uint256 _period,
        address _dex_pool_address,
        uint256 _priceUpdateThreshold
    ) {
        require(
            _pho_address != address(0) && _dex_pool_address != address(0)
                && _fraxBPPool != address(0) && _usdcAddress != address(0)
                && _fraxBPLPToken != address(0) && _fraxAddress != address(0)
                && _usdcAddress != address(0) && _priceFeed != address(0) && _period != 0,
            "PHOTWAPOracle: zero address or values detected"
        );

        pho = IPHO(_pho_address);
        fraxBPPool = ICurvePool(_fraxBPPool);
        fraxBPLP = IERC20(_fraxBPLPToken);
        fraxAddress = _fraxAddress;
        usdcAddress = _usdcAddress;
        priceFeeds = IPriceOracle(_priceFeed);
        period = _period;
        dexPool = ICurvePool(_dex_pool_address);
        initOracle = false;
        setPriceUpdateThreshold(_priceUpdateThreshold);
    }

    /// @notice queries metapool for new twap && calculates newPHOPrice (USD/PHO)
    /// @dev called directly by our own contracts that rely on an updated price (PriceController.sol)
    /// @return newPHOPrice USD/PHO updated once per `period`
    function updatePrice() external override returns (uint256) {
        require(
            dexPool.balances(0) != 0 && dexPool.balances(1) != 0,
            "PHOTWAPOracle: metapool balance(s) cannot be 0"
        );

        uint256 token0balance = dexPool.balances(0);
        uint256 token1balance = dexPool.balances(1);
        uint256 token0Price = token1balance * PRICE_PRECISION / token0balance;
        uint256 token1Price = token0balance * PRICE_PRECISION / token1balance;

        if (!initOracle) {
            twap0 = token0Price;
            twap1 = token1Price;
            latestBlockTimestamp = block.timestamp;
            priceCumulativeLast0 = token0Price;
            priceCumulativeLast1 = token1Price;
            latestUSDPHOPrice = (twap0 * _getUSDPerFraxBP()) / PRICE_PRECISION;
            initOracle = true;
            emit PriceUpdated(latestUSDPHOPrice, latestBlockTimestamp);
            return latestUSDPHOPrice;
        }

        uint256 periodTimeElapsed = block.timestamp - latestBlockTimestamp;
        require(periodTimeElapsed >= period, "PHOTWAPOracle: period not elapsed");

        uint256 priceCumulativeNew0;
        uint256 priceCumulativeNew1;
        priceCumulativeNew0 = ((token0Price) * periodTimeElapsed);
        priceCumulativeNew1 = ((token1Price) * periodTimeElapsed);

        twap0 = ((priceCumulativeNew0 - priceCumulativeLast0)) / periodTimeElapsed;
        twap1 = ((priceCumulativeNew1 - priceCumulativeLast1)) / periodTimeElapsed; // want twap[0], the price FraxBP/PHO, we keep the other just in case.

        uint256 priceBPSChange;
        uint256 oldUSDPHOPrice = latestUSDPHOPrice;
        latestUSDPHOPrice = (twap0 * _getUSDPerFraxBP()) / PRICE_PRECISION; //  UNITS: (USD/PHO) = (FraxBP/PHO * USD/FraxBP) - decimals d18

        if (latestUSDPHOPrice > oldUSDPHOPrice) {
            priceBPSChange = ((latestUSDPHOPrice - oldUSDPHOPrice))
                * UPDATEPRICE_THRESHOLD_PRECISION / oldUSDPHOPrice;
        } else {
            priceBPSChange = ((oldUSDPHOPrice - latestUSDPHOPrice))
                * UPDATEPRICE_THRESHOLD_PRECISION / oldUSDPHOPrice;
        }

        // TODO - sort out contingency plan to be implemented when price variation is greater than priceUpdateThreshold. For now, keeping basic response where last price is returned. Commented out code are conceptual for now.
        if (priceBPSChange > priceUpdateThreshold) {
            latestUSDPHOPrice = oldUSDPHOPrice;

            // thresholdExceeded = true;
            // emit PriceThresholdExceeded(thresholdExceeded);
            return latestUSDPHOPrice;
            // NOTE - need to figure out contingency plan when price fluctuates largely
        }

        // if (thresholdExceeded) {
        //     thresholdExceeded = false;
        // }

        latestBlockTimestamp = block.timestamp;
        priceCumulativeLast0 = priceCumulativeNew0;
        priceCumulativeLast1 = priceCumulativeNew1;

        emit PriceUpdated(latestUSDPHOPrice, latestBlockTimestamp);
        return latestUSDPHOPrice;
    }

    /// @notice sets the max amount the new price can differ from the last price, called the priceUpdateThreshold
    /// @param _priceUpdateThreshold the suggested price update threshold, expressed in basis points - 10 ** 6 BP corresponding to 100%
    function setPriceUpdateThreshold(uint256 _priceUpdateThreshold)
        public
        onlyByOwnerOrGovernance
    {
        require(
            _priceUpdateThreshold <= MAX_PRICE_THRESHOLD && _priceUpdateThreshold > 0,
            "PHOTWAPOracle: invalid priceUpdateThreshold value"
        );
        priceUpdateThreshold = _priceUpdateThreshold;
        emit PriceUpdateThresholdChanged(_priceUpdateThreshold);
    }

    /// @notice helper to get USD per FraxBP by checking underlying asset composition (FRAX and USDC)
    /// @return newest USD/FraxBP (normalized by d18) price answer derived from fraxBP balances and USD/Frax && USD/USDC priceFeeds
    function _getUSDPerFraxBP() internal view returns (uint256) {
        uint256 fraxInFraxBP = fraxBPPool.balances(0); // FRAX - decimals: 18
        uint256 usdcInFraxBP = fraxBPPool.balances(1); // USDC - decimals: 6
        uint256 fraxPerFraxBP = fraxInFraxBP * PRICE_PRECISION / fraxBPLP.totalSupply(); // UNITS: (FRAX/FraxBP) - normalized by d18
        uint256 usdcPerFraxBP =
            usdcInFraxBP * PRICE_PRECISION * DECIMALS_DIFFERENCE / fraxBPLP.totalSupply(); // UNITS: (USDC/FraxBP) - normalized by d18
        uint256 usdPerFraxBP = (
            (fraxPerFraxBP * PRICE_PRECISION / priceFeeds.getPrice(fraxAddress))
                + (usdcPerFraxBP * PRICE_PRECISION / priceFeeds.getPrice(usdcAddress))
        ); // UNITS: (USD/FraxBP) - normalized by d18
        return usdPerFraxBP;
    }
}
