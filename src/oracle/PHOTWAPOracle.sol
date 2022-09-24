// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../interfaces/IPHO.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/oracle/IPHOOracle.sol";
import "../interfaces/curve/ICurvePool.sol";
import "../interfaces/curve/ICurveFactory.sol";
import {IPriceFeed} from "<IPriceFeed.sol>";

/// @title PHOTWAPOracle
/// @notice Oracle exposing USD/PHO price using v1 Curve PHO/FraxBP Metapool TWAP Pair Oracle && USD PriceFeeds (USD/FRAX && USD/USDC)
/// @author Ekonomia: https://github.com/Ekonomia
/// NOTE - although dexPools can be set, underlying assets cannot stray from hardcoded Frax and USDC addresses. If dealing with new underlying assets, create a new PHOTWAPOracle with appropriate new addresses.
contract PHOTWAPOracle is IPHOOracle, Ownable {
    ICurveFactory public curveFactory; // used to query for required aspects (correct underlying assets) in setPriceSource()
    IPHO public pho;
    ICurvePool public dexPool; // curve metapool oracle is pulling balances for twap
    ICurvePool public fraxBPPool; // frax basepool (USDC && Frax underlying assets) used for normalizing FraxBP price to USD with priceFeeds
    IERC20 public fraxBPLP; // fraxBP LP Token address
    IPriceFeed public priceFeeds; 

    address public fraxAddress; 
    address public usdcAddress;
    uint256 public period; // timespan for regular TWAP updates in seconds
    bool public initOracle; // whether getPrice() has been called once or not yet
    uint256[2] public priceCumulativeLast; // used in calculating twap for both base tokens in dexPool (PHO && FraxBP)
    uint256 public latestBlockTimestamp; // last time getPrice() was called successfully
    address[2] public tokens; // used in consult() to assess which twap to use in return calculation
    uint256[2] public twap; // index 0 == PHO (units: FraxBP/PHO), index 1 == FraxBP (units: PHO/FraxBP) based off of PriceController.sol setup
    uint256 public priceUpdateThreshold; // expressed in basis points, 10 ** 6 BP corresponding to 100%

    uint256 public constant THRESHOLD_PRECISION = 10 ** 6;
    uint256 public constant FEED_PRECISION = 10 ** 8;
    uint256 public constant PRICE_PRECISION = 10 ** 18;
    uint256 public constant USDC_MISSING_DECIMALS = 12;
    uint256 public constant MAX_PRICE_THRESHOLD = 10 ** 6;

    modifier onlyByOwnerOrGovernance() {
        require(
            msg.sender == owner() || msg.sender == address(this),
            "CurveTWAPOracle: not the owner or timelock"
        );
        _;
    }

    // NOTE - make sure that dex_pool_address has PHO and FraxBP as tokens[0] and tokens[1], respectively
    // TODO - see if setPriceSource() and _setPriceUpdateThreshold() can be called in constructor, or if they have to be done after the contract is deployed.
    constructor(
        address _pho_address,
        address _curve_factory,
        address _fraxBPPool,
        address _fraxBPLPToken,
        address _fraxAddress,
        address _usdcAddress,
        uint256 _period,
        address _dex_pool_address,
        uint256 _priceUpdateThreshold
    ) {
        require(_pho_address != address(0) && _dex_pool_address != address(0) && _curve_factory != address(0) && _fraxBPPool != address(0) && _usdcAddress != address(0) && _fraxBPLPToken != address(0) && _fraxAddress != address(0) && _usdcAddress != address(0) && _period != 0, "CurveTWAPOracle: zero address or values detected");

        pho = IPHO(_pho_address);
        curveFactory = ICurveFactory(_curve_factory);
        tokens[0] = dexPool.coins(0); // PHO
        tokens[1] = dexPool.coins(1); // FraxBP LP Token
        fraxBPPool = ICurvePool(_fraxBPPool);
        fraxBPLP = IERC20(_fraxBPLPToken);
        fraxAddress = _fraxAddress;
        usdcAddress = _usdcAddress;
        period = _period;
        setPriceSource(_dex_pool_address); // TODO - don't think this is allowed in constructor
        setPriceUpdateThreshold(_priceUpdateThreshold); // TODO - not sure if I can call this here either

    }

    /// @notice queries metapool for new twap && calculates newPHOPrice (USD/PHO)
    /// @dev called directly by our own contracts that rely on an updated price (PriceController.sol)
    /// @return newPHOPrice USD/PHO updated once per `period`
    /// TODO - not sure about what the return value should be, when do we use int vs uint256? chainlink pricefeed have the getter return int. We may just want to put in a require() to get the price to make sense. 
    function getPrice() external override returns (int) {
        require(dexPool.balances(0) != 0 && dexPool.balances(1) != 0, "CurveTWAPOracle: metapool balance(s) cannot be 0");

        uint256 token0balance = dexPool.balances(0);
        uint256 token1balance = dexPool.balances(1);
        uint256 token0Price = token1balance * PRICE_PRECISION / token0balance;
        uint256 token1Price = token0balance * PRICE_PRECISION / token1balance;

        if(!initOracle) {
            require(!_requestCollatPrice, "CurveTWAPOracle: oracle not initialized");
            twap = [token0Price, token1Price];
            latestBlockTimestamp = block.timestamp;
            priceCumulativeLast = [token0Price * latestBlockTimestamp, token1Price * latestBlockTimestamp];
            uint256 newUSDPHOPrice = (twap[0] * getUSDPerFraxBP()) / PRICE_PRECISION; 
            initOracle = true;
            emit PriceUpdated(newUSDPHOPrice, latestBlockTimestamp); 
            return newUSDPHOPrice;
        }

        uint256 periodTimeElapsed = block.timestamp - latestBlockTimestamp;
        require(periodTimeElapsed >= period, "CurveTWAPOracle: period not elapsed");

        uint256[2] public priceCumulativeNew;
        priceCumulativeNew[0] = ((token0Price) * periodTimeElapsed);
        priceCumulativeNew[1] = ((token1Price) * periodTimeElapsed);
        uint256[] lastTwap;

        // NOTE - This gives weekly twap, we check this against the price threshold to ensure a robust oracle against attacks
        for(int i = 0; i < 2; i++ ) {
            lastTwap[i] = twap[i];
            twap[i] = (priceCumulativeNew[i] - priceCumulativeLast[i]) / periodTimeElapsed;
        } // want twap[0], the price FraxBP/PHO, we keep the other just in case. 

        uint256 priceBPSChange;

        if(twap[0] > lastTwap[0]){
            priceBPSChange = ((twap[0] - lastTwap[0]) * THRESHOLD_PRECISION) / lastTwap[0];
        } else {
            priceBPSChange = ((lastTwap[0] - twap[0]) * THRESHOLD_PRECISION) / lastTwap[0];
        }
        require(priceBPSChange <= priceUpdateThreshold,"CurveTWAPOracle: new twap !> priceUpdateThreshold"); // UNITS: 10 ** 6
 
        uint256 newUSDPHOPrice = (twap[0] * getUSDPerFraxBP()) / PRICE_PRECISION; //  UNITS: (USD/PHO) = (FraxBP/PHO * USD/FraxBP) - decimals d18
        latestBlockTimestamp = block.timestamp;
        priceCumulativeLast[0] = priceCumulativeNew[0];
        priceCumulativeLast[1] = priceCumulativeNew[1];

        emit PriceUpdated(newUSDPHOPrice, latestBlockTimestamp, twap);
        return newUSDPHOPrice;
    }    

    /// @notice helper to get USD per FraxBP by checking underlying asset composition (FRAX and USDC)
    /// @return newest USD/FraxBP (scaled by d18) price answer derived from fraxBP balances and USD/Frax && USD/USDC priceFeeds
    function getUSDPerFraxBP() external view returns(uint256) {
        uint256 fraxInFraxBP = fraxBPPool.balances(0); // FRAX - decimals: 18
        uint256 usdcInFraxBP = fraxBPPool.balances(1); // USDC - decimals: 6
        uint256 fraxPerFraxBP = fraxInFraxBP * PRICE_PRECISION / fraxBPLP.totalSupply(); // UNITS: (FRAX/FraxBP) - scaled by d18
        uint256 usdcPerFraxBP = usdcInFraxBP * PRICE_PRECISION * USDC_MISSING_DECIMALS / fraxBPLP.totalSupply(); // UNITS: (USDC/FraxBP) - scaled by d18
        uint256 usdPerFraxBP = ((fraxPerFraxBP / priceFeeds.getPrice(fraxAddress)) + (usdcPerFraxBP / priceFeeds.getPrice(usdcAddress))) * (FEED_PRECISION); // UNITS: (USD/FraxBP) - scaled by d18
        return usdPerFraxBP;
    }

    /// @notice calculates return amount of inputToken (only metapool basetokens) with current TWAP
    /// @param token input ERC20 metapool basetoken address
    /// @param amountIn total value of input token being priced
    /// @return amountOut price of inputToken (scaled by d18), in units of other basetoken, based on current TWAP (either FraxBP/PHO, or PHO/FraxBP) 
    /// NOTE this will always return 0 before getPrice() has been called successfully for the first time
    /// NOTE I'm not sure when this would be used tbh, maybe a front end getter for specified input values? The Curve Metapool should have this actually though so don't know if we'd be using this.
    function consult(address _token, uint256 _amountIn) external override view returns (uint256) {
        require(initOracle, "CurveTWAPOracle: CurveTWAPOracle not initialized");
        if (_token == tokens[0]) {
            amountOut = twap[0] * (_amountIn) / PRICE_PRECISION;  
        } else {
            require(_token == tokens[1], "CurveTWAPOracle: invalid token");
            amountOut = twap[1] * (_amountIn) / PRICE_PRECISION;
        }
        return amountOut;
    }

    /// @notice set the price source (dex pool) address that this contract interacts with
    /// @dev likely rare that the metapool needs to be set again, but in case curve upgrades and we have new metapools that are compatible, this is available 
    /// @param _priceSource address for metapool that twap is derived from for FraxBP/PHO
    function setPriceSource(address _priceSource) external onlyByOwnerOrGovernance {
        require(_newDexPool != address(0), "CurveTWAPOracle: zero address detected");
        require(
            curveFactory.is_meta(_newDexPool),
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
        emit PriceSourceUpdated(newDexPool);
    }

    /// @notice sets the suggested price update threshold
    /// @param _priceUpdateThreshold the suggested price update threshold, expressed in basis points - 10 ** 6 BP corresponding to 100%
    function setPriceUpdateThreshold(uint256 _priceUpdateThreshold) external onlyByOwnerOrGovernance {
        require(_priceUpdateThreshold <= MAX_PRICE_THRESHOLD && _priceUpdateThreshold > 0, "CurveTWAPOracle: invalid priceUpdateThreshold value");
        priceUpdateThreshold = _priceUpdateThreshold;
        emit PriceUpdateThresholdChanged(_priceUpdateThreshold);
    }  

}
