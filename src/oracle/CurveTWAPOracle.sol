// SPDX-License-Identifier: GPL-3.0-or-later
// Inpired by LIDO, UNISWAP, CURVE, and BEANSTALK
// <INSERT GITHUB URLS HERE>

pragma solidity ^0.8.13;

import "../interfaces/IPHO.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/oracle/IPHOPriceFeed.sol";
import "../interfaces/curve/ICurvePool.sol";
import "../interfaces/curve/ICurveFactory.sol";

/// @title CurveTWAPOracle
/// @notice Generic TWAP Oracle for v1 Curve Metapools that exposes getter for TWAP
/// @author Ekonomia: https://github.com/Ekonomia
/// NOTE - Later versions of this oracle can look into getting more precision through the use of uint112 and UQ112.112 format as per uniswap's implementation for price oracles. Gas efficiencies can be considered too of course.
/// NOTE - This could be easily replaced by new curve pool contracts that are implementing exposed oracle functionality as per talks with Fiddy (CURVE)
contract CurveTWAPOracle is IPHOPriceFeed, Ownable {
    IPHO public pho;
    ICurvePool public dexPool;
    ICurveFactory public curveFactory;
    
    int128 public constant N_COINS = 2;
    uint public period; // timespan for regular TWAP updates
    bool public initOracle;
   
    uint256[N_COINS] public firstBalances;
    uint256[N_COINS] public priceCumulativeLast;
    uint256 public blockTimestampLast;
    address[N_COINS] public tokens;
    uint256[N_COINS] public balances; 
    uint256[N_COINS] public twap; // index 0 == PHO, index 1 == FraxBP based off of PriceController.sol
    uint256 public priceUpdateThreshold; // The initial value of the suggested price update threshold. Expressed in basis points, 10000 BP corresponding to 100%

    constructor(
        uint256 _priceUpdateThreshold,
        uint _period,
        address _pho_address,
        address _dex_pool_address,
        address _curve_factory
    ) {
        require(_pho_address != address(0), "CurveTWAPOracle: zero address detected");
        require(_dex_pool_address != address(0), "CurveTWAPOracle: zero address detected");
        require(_curve_factory != address(0), "CurveTWAPOracle: zero address detected");
        require(_period != 0, "CurveTWAPOracle: period cannot be zero");
        pho = IPHO(_pho_address);
        setDexPool(_dex_pool_address);
        curveFactory = ICurveFactory(_curve_factory);
        _setPriceUpdateThreshold(_priceUpdateThreshold);
        period = _period;
        tokens = dexPool.coins;
    }

    /// @notice queries metapool for new balances && calculates twap
    /// @return twap of PHO in as ($FRAXBP / $1 PHO) updated once per `period`
    /// @dev this can be externally called, but is going to be called directly by our own contracts that rely on an updated price (PriceController.sol)
    /// NOTE - twap is wrt to underlying assets within dexpool, which are stable, so price is assumed accurate as PHO/USD
    /// TODO - May need to switch the return so it is just a unit256 for the PHO price, not the array. TBD based on PriceController, etc.
    function getPHOUSDPrice() external override returns (uint256[2] calldata) {
        require(dexPool.balances(0) != 0 && dexPool.balances(1) != 0, "getPHOUSDPrice(): metapool balance(s) cannot be 0");
        // check if at initialization stage
        if(initOracle != true) {
            uint256 token0Price = dexPool.balances(1) / dexPool.balances(0);
            uint256 token1Price = dexPool.balances(0) / dexPool.balances(1);
            blockTimestampLast = block.timestamp;
            firstTimestamp = blockTimestampLast;
            firstBalances[0] = token0Price * blockTimestampLast;
            firstBalances[1] = token1Price * blockTimestampLast;
            twap = [token0Price, token1Price];
            priceCumulativeLast = [firstBalances[0], firstBalances[1]];
            initOracle = true;
            emit PriceFeedInitialized(twap, blockTimestampLast);
            return twap;
        }
        uint256 periodTimeElapsed = block.timestamp - blockTimestampLast;
        require(periodTimeElapsed >= period, "getPHOUSDPrice): period not elapsed");
        uint256 totalTimeElapsed = block.timestamp - firstTimestamp; // time since initial TWAP balances in seconds
        priceCumulativeLast[0] = priceCumulativeLast[0] + ((dexPool.balances(1) / dexPool.balances(0)) * periodTimeElapsed);
        priceCumulativeLast[1] = priceCumulativeLast[1] + ((dexPool.balances(0) / dexPool.balances(1)) * periodTimeElapsed);
        
        for(int i = 0; i < N_COINS; i++ ) {
            twap[i] =(priceCumulativeLast[i] - firstBalances[i]) / totalTimeElapsed;
        }

        blockTimestampLast = block.timestamp;
        emit PriceUpdated(twap, blockTimestampLast);
        return twap;
    }    

    
    /// @notice calculates price of inputToken with current TWAP
    /// @param token input ERC20 address
    /// @param amountIn total value being priced
    /// @return amountOut price of inputToken based on current TWAP
    /// NOTE this will always return 0 before getPHOUSDPrice() has been called successfully for the first time
    function consult(address token, uint amountIn) external override view returns (uint256) {
        require(initOracle = true, "consult(): CurveTWAPOracle not initialized");
        if (token == tokens[0]) {
            amountOut = twap[0] * (amountIn);
        } else {
            require(token == tokens[1], "consult(): invalid token");
            amountOut = twap[1] * (amountIn);
        }
        return amountOut;

    }

    /// @notice Sets the suggested price update threshold.
    /// @param _priceUpdateThreshold The suggested price update threshold. Expressed in basis points, 10000 BP corresponding to 100%
    function setPriceUpdateThreshold(uint256 _priceUpdateThreshold) external {
        _setPriceUpdateThreshold(_priceUpdateThreshold);
    }

    /// @notice set the dex pool address that this contract interacts with
    function setDexPool(address newDexPool) external onlyByOwnerGovernanceOrController {
        require(newDexPool != address(0), "CurveTWAPOracle: zero address detected");
        require(
            curveFactory.is_meta(newDexPool),
            "CurveTWAPOracle: address does not point to a metapool"
        );

        address[8] memory underlyingCoins = curveFactory.get_underlying_coins(newDexPool);
        bool isPhoPresent = false;
        for (uint256 i = 0; i < underlyingCoins.length; i++) {
            if (underlyingCoins[i] == address(pho)) {
                isPhoPresent = true;
                break;
            }
        }
        require(isPhoPresent, "CurveTWAPOracle: $PHO is not present in the metapool");

        dexPool = ICurvePool(newDexPool);
        emit DexPoolUpdated(newDexPool);
    }

    /// @notice sets priceUpdateThreshold used to control against volatility
    function _setPriceUpdateThreshold(uint256 _priceUpdateThreshold) internal {
        require(_priceUpdateThreshold <= 10000, "_setPriceUpdateThreshold(): priceUpdateThreshold !> 10000");
        priceUpdateThreshold = _priceUpdateThreshold;
        emit PriceUpdateThresholdChanged(_priceUpdateThreshold);
    }

    
    
}
