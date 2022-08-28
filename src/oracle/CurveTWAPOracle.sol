// SPDX-License-Identifier: GPL-3.0-or-later
// Inpired by LIDO, UNISWAP, CURVE, and BEANSTALK
// <INSERT GITHUB URLS HERE>
// curve_factory_address="0xB9fC157394Af804a3578134A6585C0dc9cc990d4";
// frax_bp_address="0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2";
// frax_bp_lp_address="0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC";

pragma solidity ^0.8.13;

import "../interfaces/ICurve.sol";
// import "@curve/pool-templates/meta/SwapTemplateMeta.vy";

/// @title CurveTWAPOracle
/// @notice Generic TWAP Oracle for v1 Curve Metapools that exposes getter for TWAP
/// @author Ekonomia: https://github.com/Ekonomia
/// @dev NOTE - Curve contracts are written in vyper, so there may be some compatibility aspects that I need to look into for solidity to vyper. In theory it should be alright... the solidity files will be deployed to mainnet, and this can be tested with local mainnet fork too.
/// @dev CurveTWAPOracle relies on IPriceHelper
/// NOTE - Later versions of this oracle can look into getting more precision through the use of uint112 and UQ112.112 format as per uniswap's implementation for price oracles. Gas efficiencies can be considered too of course.
/// NOTE - This could be easily replaced by new curve pool contracts that are implementing exposed oracle functionality as per talks with Fiddy (CURVE)
contract CurveTWAPOracle is IStableSwap {
    address pidControllerAddress;
    ICurve curvePool;
    bool initOracle;
    int128 public constant N_COINS = 2;
    uint public period;

    uint256[N_COINS] firstBalances;
    uint256[N_COINS] priceCumulativeLast;
    uint256 public blockTimestampLast;
    address[N_COINS] tokens;
    uint256[N_COINS] public balances; 
    uint256[N_COINS] twap; // TODO - MAYBE for underlying assets, we'll have to figure out how to get their prices accordingly too. This would just supply the price of FraxBP to EUSD

    // unsure vars
    uint256 public constant PRECISION = 10 ** 18;

    /// EVENTS

    event PriceUpdateThresholdChanged(uint256 priceUpdateThreshold);
    
    /// @notice getTWAP called successfully for first time where return vars are initial prices
    event TWAPInitialized(uint256[N_COINS] indexed twap, uint256 indexed blockTimestampLast);
    
    /// @notice getTWAP called and TWAP updated
    event TWAPUpdated(uint256[N_COINS] indexed twap, uint256 indexed blockTimestampLast);

    /// MODIFIERS
    
    /// TODO - not sure if this will be used, I would think that we need restriction to some degree for price updates but perhaps not.
    modifier onlyPID() {
        require(msg.sender == pidControllerAddress, "Only PIDController allowed to call this function");
        _;
    }

    /// CONSTRUCTOR

    /// @dev TODO: likely to make this contract ownable or use AccessRoles, && need to figure out if priceUpdateThreshold will be used to control against volatile price feeds from DEX pair oracle
    /// @param _priceUpdateThreshold The initial value of the suggested price update threshold. Expressed in basis points, 10000 BP corresponding to 100%
    /// @param _curvePool address of metapool used for oracle
    /// @param _period timespan for regular TWAP updates
    /// TODO - assign tokens within constructor from curve metapool
    constructor(
        uint256 _priceUpdateThreshold,
        address _curvePool,
        uint _period
    ) {
        _setPriceUpdateThreshold(_priceUpdateThreshold);
        curvePool = ICurve(_curvePool);
        period = _period;
        require(curvePool.balances(0) != 0, curvePool.balances(1) != 0, "Constructor: no reserves in metapool");
    }

    /// FUNCTIONS

    /// @notice queries metapool for new balances && calculates twap
    /// @return twap updated once per `period`
    /// @dev I think this can be externally called, but is going to be called directly by our own contracts that rely on an updated price (PIDController.sol - `refreshCollateralRatio()`)
    function getTWAP() external returns (uint256[2] twap) {

        require(curvePool.balances(0) != 0 && curvePool.balances(1) != 0, "getTWAP(): metapool balance(s) cannot be 0");
        // check if at initialization stage
        if(initOracle != true) {
            firstBalances[0] = curvePool.balances(0) * (block.timestamp);
            firstBalances[1] = curvePool.balances(1) * block.timestamp;
            uint256 token0Price = curvePool.balances(1) / curvePool.balances(0);
            uint256 token1Price = curvePool.balances(0) / curvePool.balances(1);

            twap = [token0Price, token1Price];
            blockTimestampLast = block.timestamp;

            priceCumulativeLast = [firstBalances[0], firstBalances[1]];
            initOracle = true;

            emit TWAPInitialized(twap, blockTimestampLast);
            return twap;
        }

        uint256 totalTimeElapsed = block.timestamp - firstTimestamp; // time since initial TWAP balances in seconds
        uint256 periodTimeElapsed = block.timestamp - blockTimestampLast;
        require(timeElapsed >= period, "getTWAP(): period not elapsed");

        priceCumulativeLast[0] = priceCumulativeLast[0] + (curvePool.balances(0) * periodTimeElapsed);
        priceCumulativeLast[1] = priceCumulativeLast[1] + (curvePool.balances(1) * periodTimeElapsed);

        for(int i = 0; i < N_COINS; i++ ) {
            twap[i] =(priceCumulativeLast[i] - firstBalances[i]) / totalTimeElapsed;
        }

        blockTimestampLast = block.timestamp;
        emit TWAPUpdated(twap, blockTimestampLast);
    }    

    
    /// @notice calculates price of inputToken with current twap
    /// NOTE this will always return 0 before update has been called successfully for the first time
    /// @dev NOTE - pulled from uniswap oracleSimple, but this is used in FRAX.sol, or at least the function signature to get the price of token
    function consult(address token, uint amountIn) external view returns (uint amountOut) {
        require(initOracle = true, "consult(): CurveTWAPOracle not initialized");
        if (token == tokens[0]) {
            amountOut = twap[0] * (amountIn);
        } else {
            require(token == tokens[1], "consult(): invalid token");
            amountOut = twap[1] * (amountIn);
        }
    }

    /// @notice Sets the suggested price update threshold.
    /// @param _priceUpdateThreshold The suggested price update threshold. Expressed in basis points, 10000 BP corresponding to 100%
    function setPriceUpdateThreshold(uint256 _priceUpdateThreshold) external {
        _setPriceUpdateThreshold(_priceUpdateThreshold);
    }

    /// INTERNAL FUNCTIONS

    /// @notice sets priceUpdateThreshold used to control against volatility
    /// @dev TODO - assess if this needs to be in price oracle
    function _setPriceUpdateThreshold(uint256 _priceUpdateThreshold) internal {
        require(_priceUpdateThreshold <= 10000);
        priceUpdateThreshold = _priceUpdateThreshold;
        emit PriceUpdateThresholdChanged(_priceUpdateThreshold);
    }
}
