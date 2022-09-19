// SPDX-License-Identifier: GPL-3.0-or-later
// Inpired by LIDO, UNISWAP, CURVE, and BEANSTALK
// <INSERT GITHUB URLS HERE>

pragma solidity ^0.8.13;

import "../interfaces/IPHO.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/oracle/IOracle.sol";
import "../interfaces/curve/ICurvePool.sol";
import "../interfaces/curve/ICurveFactory.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/// @title CurveTWAPOracle
/// @notice Generic TWAP Oracle for v1 Curve Metapools that exposes getter for TWAP
/// @author Ekonomia: https://github.com/Ekonomia
/// TODO - solidity doesn't like fractions.
contract CurveTWAPOracle is IOracle, Ownable {
    IPHO public pho;
    address public fraxBPAddress;
    ICurvePool public dexPool;
    ICurveFactory public curveFactory;
    ICurvePool public fraxBPPool;
    AggregatorV3Interface[] public priceFeeds; // 0 = USD/ETH, 1 = USD/USDC, 2 = USD/Frax, etc.

    uint public period; // timespan for regular TWAP updates in seconds
    bool public initOracle;
   
    uint256[2] public firstBalances; // used in calculating TWAP, first balances of dexpool
    uint256[2] public priceCumulativeLast;
    uint256 public blockTimestampLast;
    address[2] public tokens;
    // mapping(address => uint256) public prices; // TODO - not sure if we need this, it's really just a public getter
    uint256[2] public twap; // index 0 == PHO, index 1 == FraxBP based off of PriceController.sol
    uint256 public priceUpdateThreshold; // The initial value of the suggested price update threshold. Expressed in basis points, 10 ** 6 BP corresponding to 100%

    modifier onlyByOwnerOrGovernance() {
        require(
            msg.sender == owner() || msg.sender == address(this),
            "CurveTWAPOracle: not the owner or timelock"
        );
        _;
    }

    // NOTE - make sure that dex_pool_address has PHO and FraxBP as tokens[0] and tokens[1], respectively
    constructor(
        uint256 _priceUpdateThreshold,
        uint256 _period,
        address _pho_address,
        address _dex_pool_address,
        address _curve_factory,
        address _fraxBPPool,
        address _fraxBPAddress,
        address _priceFeedEthUSD,
        address _priceFeedUSDC,
        address _priceFeedFrax
    ) {
        require(_pho_address != address(0) || _dex_pool_address != address(0) || _curve_factory != address(0) || _period != 0 || _priceFeedETHUSD != address(0) || _priceFeedUSDC != address(0) || _priceFeedFrax != address(0), "CurveTWAPOracle: zero address or values detected");

        pho = IPHO(_pho_address);
        setDexPool(_dex_pool_address); // TODO - don't think this is allowed in constructor
        curveFactory = ICurveFactory(_curve_factory);
        _setPriceUpdateThreshold(_priceUpdateThreshold);
        period = _period;
        tokens[0] = dexPool.coins(0); // PHO
        tokens[1] = dexPool.coins(1); // FraxBP
        fraxBPPool = ICurvePool(_fraxBPPool);
        fraxBPAddress = _fraxBPAddress;
        priceFeeds[0] = AggregatorV3Interface(_priceFeedEthUSD);
        priceFeeds[1] = AggregatorV3Interface(_priceFeedUSDC);
        priceFeeds[2] = AggregatorV3Interface(_priceFeedFrax);
    }

    /// @notice queries metapool for new balances && calculates twap
    /// @return usd/collateral or usd/pho updated once per `period`
    /// @dev called directly by our own contracts that rely on an updated price (PriceController.sol)
    /// @param _priceFeedIndex specifying id for collateral of interest where: 0 = USD/ETH, 1 = USD/USDC, 2 = USD/Frax, etc. (see registerPriceFeed())
    /// @param _requestCollatPrice whether this call is for collateral pricing or PHO pricing only
    /// @return new price in units USD/PHO or PHO/Collateral
    /// TODO - not sure about what the return value should be, when do we use int vs uint256? chainlink pricefeed have the getter return int
    function getPrice(uint8 _priceFeedIndex, bool _requestCollatPrice) external override returns (int) {
        require(dexPool.balances(0) != 0 && dexPool.balances(1) != 0, "CurveTWAPOracle: metapool balance(s) cannot be 0");
        uint256 token0balance = dexPool.balances(0);
        uint256 token1balance = dexPool.balances(1);

        // check if at initialization stage
        if(!initOracle) {
            require(!_requestCollatPrice, "CurveTWAPOracle: oracle not initialized");
            uint256 token0Price = token1balance / token0balance;
            uint256 token1Price = token0balance / token1balance;
            blockTimestampLast = block.timestamp;
            firstTimestamp = blockTimestampLast;
            firstBalances[0] = token0Price * blockTimestampLast;
            firstBalances[1] = token1Price * blockTimestampLast;
            twap = [token0Price, token1Price];
            priceCumulativeLast = [firstBalances[0], firstBalances[1]];
            uint256 newUSDPHOPrice = twap[0] * getUSDPerFraxBP();            
            initOracle = true;
            emit PriceUpdated(newUSDPHOPrice, blockTimestampLast, 0); // no collatPrice requested, returns 0 for collatPrice in emitted event
            return newUSDPHOPrice;
        }

        uint256 periodTimeElapsed = block.timestamp - blockTimestampLast;
        require(periodTimeElapsed >= period, "CurveTWAPOracle: period not elapsed");
        uint256 totalTimeElapsed = block.timestamp - firstTimestamp; // time since initial TWAP balances in seconds
        priceCumulativeLast[0] = priceCumulativeLast[0] + ((token1balance / token0balance) * periodTimeElapsed);
        priceCumulativeLast[1] = priceCumulativeLast[1] + ((token0balance / token1balance) * periodTimeElapsed);

        for(int i = 0; i < 2; i++ ) {
            twap[i] = (priceCumulativeLast[i] - firstBalances[i]) / totalTimeElapsed;
            // if(dexPool.coins(i) == _tokenAddress) {
            //     prices(fraxBPAddress) = twap[i];
            // } else {
            //     prices(address(pho)) = twap[i];
            // }
        } // want twap[0], the price FraxBP/PHO, we keep the other just in case.
        
        uint256 newUSDPHOPrice = twap[0] * getUSDPerFraxBP(); //  UNITS: (USD/PHO) = (FraxBP/PHO * USD/FraxBP)
        blockTimestampLast = block.timestamp;

        /// Add conditional logic checking if caller is asking for collateral price wrt to PHO.
        /// NOTE - instead of an array, there could be a better way to go about this.
        if(!requestCollatPrice) {
            emit PriceUpdated(twap[0], blockTimestampLast, 0); // no collatPrice requested, returns 0 for collatPrice in emitted event
            return newUSDPHOPrice;
        }

        int collatUSDPrice = getLatestPrice(_priceFeedIndex);
        emit PriceUpdated(newUSDPHOPrice, blockTimestampLast, collatUSDPrice / newUSDPHOPrice); // no collatPrice requested, returns 0 for collatPrice in emitted event
        return collatUSDPrice / newUSDPHOPrice; // UNITS: (PHO/Collat) = (USD/Collat / USD/PHO) 
     }    

    /// @notice calculates price of inputToken (only metapool basetokens) with current TWAP
    /// @param token input ERC20 address
    /// @param amountIn total value being priced
    /// @return amountOut price of inputToken, in units of other basetoken, based on current TWAP (either FraxBP/PHO, or PHO/FraxBP)
    /// NOTE this will always return 0 before getPrice() has been called successfully for the first time
    /// NOTE I'm not sure when this would be used tbh
    function consult(address token, uint amountIn) external override view returns (uint256) {
        require(initOracle, "CurveTWAPOracle: CurveTWAPOracle not initialized");
        if (token == tokens[0]) {
            amountOut = twap[0] * (amountIn);
        } else {
            require(token == tokens[1], "CurveTWAPOracle: invalid token");
            amountOut = twap[1] * (amountIn);
        }
        return amountOut;
    }

    /// @notice Sets the suggested price update threshold.
    /// @param _priceUpdateThreshold The suggested price update threshold. Expressed in basis points, 10 ** 6 BP corresponding to 100%
    /// TODO - implement so getPrice reverts if newPrice is >> priceTarget by the Threshold.
    function setPriceUpdateThreshold(uint256 _priceUpdateThreshold) external onlyByOwnerOrGovernance {
        _setPriceUpdateThreshold(_priceUpdateThreshold);
    }

    /// @notice set the dex pool address that this contract interacts with
    /// @param newDexPool address for metapool that twap is derived from for FraxBP/PHO
    function setDexPool(address newDexPool) external onlyByOwnerOrGovernance {
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
    /// @param _priceUpdateThreshold The suggested price update threshold. Expressed in basis points, 10 ** 6 BP corresponding to 100%
    function _setPriceUpdateThreshold(uint256 _priceUpdateThreshold) internal {
        require(_priceUpdateThreshold <= 10000, "CurveTWAPOracle: priceUpdateThreshold !> (10 ** 6)");
        priceUpdateThreshold = _priceUpdateThreshold;
        emit PriceUpdateThresholdChanged(_priceUpdateThreshold);
    }

    /// @notice helper to get USD per FraxBP by checking underlying asset composition (FRAX and USDC)
    /// @return newest USD per FraxBP price answer derived from fraxBP balances and USD/Frax && USD/USDC priceFeeds
    function getUSDPerFraxBP() external view returns(uint256) {
        uint256 fraxInFraxBP = fraxBPPool.balances(0); // frax
        uint256 usdcInFraxBP = fraxBPPool.balances(1); // usdc
        uint256 fraxPerFraxBP = fraxInFraxBP / fraxBPPool.totalSupply(); // UNITS: (FRAX/FraxBP)
        uint256 usdcPerFraxBP = usdcInFraxBP / fraxBPPool.totalSupply(); // UNITS: (USDC/FraxBP)
        uint256 totalTVLInFraxBP = fraxInFraxBP + usdcInFraxBP;
        uint256 usdPerFraxBP = ((fraxPerFraxBP * (fraxInFraxBP / totalTVLInFraxBP)) * getLatestPrice(2)) + ((usdcPerFraxBP * (usdcInFraxBP / totalTVLInFraxBP)) * getLatestPrice(1)); // UNITS: (USD/FraxBP) 
        return usdPerFraxBP;
    }

    /// @notice registers new price feeds or replaces old ones
    /// @param priceFeed aggregator address
    /// @param tokens specify which priceFeed
    /// NOTE - we add price feeds bc we may need more down the line. Ex.) Dispatcher.sol calls on various collateral prices wrt to PHO. As we increase # of vaults we have, we'll need more pricefeeds.
    function registerPriceFeed(uint8 _priceFeedIndex, address _priceFeed) external onlyByOwnerOrGovernance {
        require(_priceFeed != address(0), "CurveTWAPOracle: zero address detected");
        AggregatorV3Interface newPriceFeed = AggregatorV3Interface(_priceFeed);
        if(_priceFeedIndex < priceFeeds.length){
            require(priceFeeds[_priceFeedIndex] != AggregatorV3Interface(_priceFeed),"CurveTWAPOracle: pricefeed already registered");
            priceFeeds[_priceFeedIndex] = newPriceFeed;
        } else {
            priceFeeds.push(newPriceFeed);
        }
        emit PriceFeedUpdated(_priceFeed, _priceFeedIndex);
    }

    /// @notice gets latest price from specified priceFeed
    /// @param _priceFeedIndex specifies pricefeed of interest
    /// @return latest price from pricefeed (always USD/token)
    function getLatestPrice(uint8 _priceFeedIndex) public view returns (int) {
        require(_priceFeedIndex < priceFeeds.length, "CurveTWAPOracle: _priceFeedIndex does not exist");
        AggregatorV3Interface priceFeed = priceFeeds[_priceFeedIndex];
        (
            /*uint80 roundID*/,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();
        return price;
    }
    
}
