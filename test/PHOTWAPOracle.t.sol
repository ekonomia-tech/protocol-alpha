// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import "./BaseSetup.t.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {PHO} from "../src/contracts/PHO.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "src/interfaces/curve/ICurvePool.sol";
import "src/interfaces/curve/ICurveFactory.sol";
import {PHOTWAPOracle} from "../src/oracle/PHOTWAPOracle.sol";
// import "./Console.sol";

/// @notice basic tests assessing genesis PHOTWAPOracle
/// @dev for function sigs in metapool, see https://etherscan.io/address/0x497CE58F34605B9944E6b15EcafE6b001206fd25#code
contract PHOTWAPOracleTest is BaseSetup {

    ICurvePool public curvePool;
    ERC20 public fraxBPPhoLP;
    address public fraxBPPhoMetapoolAddress;
    PHOTWAPOracle public phoTwapOracle;

    // PHOTWAPOracle public phoTwapOracle;

    /// EVENTS

    event PriceUpdated(uint256 indexed latestPHOUSDPrice, uint256 indexed blockTimestampLast);
    event PriceSourceUpdated(address indexed priceSource); 
    event PriceUpdateThresholdChanged(uint256 priceUpdateThreshold);

    uint256 poolMintAmount = 99750000;
    uint256 shareBurnAmount = 25 * 10 ** 16;
    uint256 minPHOOut = 80 * 10 ** 18;

    /// @notice setup PHOTWAPOracle with 1 million PHO && 1 million FraxBP (33% USDC, 33% FRAX, 33% PHO) or (66% FraxBP, and 33% PHO)
    function setUp() public {
        // NOTE - I think this setup should go to baseSetup, but we need to confirm that the dexPool should actually be set up within baseSetup as well.
        vm.startPrank(owner);
        // set base pricefeeds needed for PHOTWAPOracle
        priceFeed.addFeed(fraxAddress, PriceFeed_FRAXUSD); // https://data.chain.link/ethereum/mainnet/stablecoins/frax-usd
        priceFeed.addFeed(USDC_ADDRESS, PriceFeed_USDCUSD); // https://data.chain.link/ethereum/mainnet/stablecoins/usdc-usd
        priceFeed.addFeed(ethNullAddress, PriceFeed_ETHUSD); // https://data.chain.link/ethereum/mainnet/crypto-usd/eth-usd
        vm.stopPrank();
        fraxBPPhoMetapool = ICurvePool(_deployFraxBPPHOPoolOneMillion()); // deploy FRAXBP-PHO metapool
        fraxBPPhoMetapoolAddress = address(fraxBPPhoMetapool);

        vm.startPrank(owner);
        phoTwapOracle = new PHOTWAPOracle(address(pho), metaPoolFactoryAddress, fraxBPPool, fraxBPLPToken, fraxAddress, USDC_ADDRESS, address(priceFeed), period, fraxBPPhoMetapoolAddress, PRICE_THRESHOLD); // deploy PHOTWAPOracle
        fraxBPPhoMetapool = phoTwapOracle.dexPool();
        pho.approve(fraxBPPhoMetapoolAddress, fiveHundredThousand_d18);
        vm.stopPrank();
        // TODO - Below only needed if within the constructor doesn't work, otherwise delete below lines
        // phoTwapOracle.setPriceSource(address(fraxBPPhoMetapool)); 
        // phoTwapOracle.setPriceUpdateThreshold(PRICE_THRESHOLD);
    }

    // function testSetup() public {}

    /// constructor() tests
    // TODO - add two extra asserts from niv and you
    function testPHOTWAPOracleConstructor() public {
        address phoTwapTokens = phoTwapOracle.tokens(0);
        address phoTwapToken0 = phoTwapOracle.tokens(0);
        address phoTwapToken1 = phoTwapOracle.tokens(1);

        assertEq(address(phoTwapOracle.pho()), address(pho));
        assertEq(address(phoTwapOracle.curveFactory()), metaPoolFactoryAddress);
        assertEq(address(phoTwapOracle.fraxBPPool()), fraxBPPool);
        assertEq(address(phoTwapOracle.fraxBPLP()), fraxBPLPToken);
        assertEq(phoTwapOracle.fraxAddress(), fraxAddress);
        assertEq(phoTwapOracle.usdcAddress(), USDC_ADDRESS);
        assertEq(phoTwapOracle.period(), period);
        assertEq(address(phoTwapOracle.dexPool()), fraxBPPhoMetapoolAddress);
        assertEq(phoTwapOracle.priceUpdateThreshold(), PRICE_THRESHOLD);
        assertEq(phoTwapOracle.initOracle(), false);
        assertEq(phoTwapToken0, fraxBPPhoMetapool.coins(0));
        assertEq(phoTwapToken1, fraxBPPhoMetapool.coins(1));
        assertEq(phoTwapToken0, address(pho));
        assertEq(phoTwapToken1, fraxBPLPToken); // NOTE - see PriceController.t.sol line 437, should we use get_coin_indices() or something like it to get the dynamic indices for the PHO-FraxBP metapool base tokens?
        assertEq(0, phoTwapOracle.latestBlockTimestamp());

    }

    // /// getPrice() tests

    // function testCannotGetPrice() public {
    //     vm.startPrank(owner);
    //     fraxBPPhoMetapool.remove_liquidity(fraxBPPhoMetapool.balanceOf(owner), [0,0]); // remove all liquidity
    //     vm.expectRevert("PHOTWAPOracle: metapool balance(s) cannot be 0");
    //     phoTwapOracle.getPrice();
    //     vm.stopPrank();
    // }

    /// @notice check newPHOUSDPrice against manual calculations with genesis liquidity
    function testInitialGetPrice() public {
        uint256 expectedPeriodTimeElapsed = block.timestamp;
        uint256 expectedTWAP0 = fraxBPLP.balanceOf(fraxBPPhoMetapoolAddress) * PHO_PRICE_PRECISION / pho.balanceOf(fraxBPPhoMetapoolAddress); 
        uint256 expectedTWAP1 = pho.balanceOf(fraxBPPhoMetapoolAddress) * PHO_PRICE_PRECISION / fraxBPLP.balanceOf(fraxBPPhoMetapoolAddress); 
        uint256 expectedBlockTimeStamp = block.timestamp;
        uint256 expectedPriceCumulativeLast0 = expectedBlockTimeStamp * expectedTWAP0;
        uint256 expectedPriceCumulativeLast1 = expectedBlockTimeStamp * expectedTWAP1;
        uint256 expectedNewUSDPHOPrice = expectedTWAP0 * _getUSDPerFraxBP() / PHO_PRICE_PRECISION;
        uint256 oldUSDPHOPrice = phoTwapOracle.latestUSDPHOPrice();

        assertEq(expectedPeriodTimeElapsed, block.timestamp - phoTwapOracle.latestBlockTimestamp()); //latestBlockTimestamp should be zero

        // console.log("balances(0): %s", fraxBPPhoMetapool.balances(0));
        // console.log("balances(1): %s", fraxBPPhoMetapool.balances(1));
        // console.log("TEST(_getUSDPerFraxBP(): %s", phoTwapOracle._getUSDPerFraxBP());
        // console.log("TEST - fraxInFraxBP: %s", fraxBP.balances(0));
        // console.log("TEST - InFraxBP: %s", fraxBP.balances(1));
        // console.log("TEST - usdcInFraxBP: %s", fraxBP.balances(1));
        // console.log("TEST - fraxBPLP total supply: %s", fraxBPLP.totalSupply());
        // console.log("Chainlink Prices: frax %s, usdc %s", priceFeed.getPrice(fraxAddress), priceFeed.getPrice(USDC_ADDRESS));

        vm.expectEmit(true, true, false, true);
        emit PriceUpdated(expectedNewUSDPHOPrice, expectedBlockTimeStamp);
        uint256 newUSDPHOPrice = phoTwapOracle.getPrice();

        assertEq(expectedNewUSDPHOPrice, phoTwapOracle.latestUSDPHOPrice());
        // console.log("expectedNewUSDPHOPrice: %s and latestUSDPHOPrice: %s and oldUSDPHOPrice: %s", expectedNewUSDPHOPrice, phoTwapOracle.latestUSDPHOPrice(), oldUSDPHOPrice);
        assertEq(phoTwapOracle.initOracle(), true);
        assertEq(expectedPriceCumulativeLast0, phoTwapOracle.priceCumulativeLast(0));
        assertEq(expectedPriceCumulativeLast1, phoTwapOracle.priceCumulativeLast(1));
        assertEq(expectedBlockTimeStamp, phoTwapOracle.latestBlockTimestamp());
        assertEq(expectedTWAP0, phoTwapOracle.twap(0));
        assertEq(expectedTWAP1, phoTwapOracle.twap(1));
    }

    /// @notice test getPrice() after doing the first significant swap in the metapool: swapping token 0 for token 1
    /// NOTE - accuracy is tbd
    function testGetPriceSwapToken0() public {    
        twapFixture(); // getPrice() called for first time, and we've fast forwarded 1 period

        uint256 oldUSDPHOPrice = phoTwapOracle.latestUSDPHOPrice();

        vm.startPrank(owner); 
        fraxBPPhoMetapool.exchange(0, 1, tenThousand_d18, tenThousand_d18); // TODO - not sure if the minimum amount greatly affects the returnValue
        uint256 expectedNewUSDPHOPrice = _getNewUSDPHOPrice();
        console.log("expectedNewUSDPHOPrice: %s and oldUSDPHOPrice: %s", expectedNewUSDPHOPrice, phoTwapOracle.latestUSDPHOPrice(), oldUSDPHOPrice);
                
        // vm.expectEmit(true, true, false, true);
        // emit PriceUpdated(expectedNewUSDPHOPrice, block.timestamp);
        // phoTwapOracle.getPrice();

        
        // console.log("expectedNewUSDPHOPrice: %s and latestUSDPHOPrice: %s and oldUSDPHOPrice: %s", expectedNewUSDPHOPrice, phoTwapOracle.latestUSDPHOPrice(), oldUSDPHOPrice);


        // assertEq(expectedNewUSDPHOPrice, phoTwapOracle.latestUSDPHOPrice());
        // assertEq(block.timestamp, phoTwapOracle.latestBlockTimestamp());
        vm.stopPrank();
    }

    // TODO - come up with test that tests the exact tipping point for allowed threshold. This is more just for tests, no extra code should be needed in the implemented contract, PHOTWAPOracle.sol for this. Essentially: calc backwards, what is the threshold, basically come out with the priceAllowed && then use that to calculate the change in balances that can be allowed essentially.

    // /// @notice same as last test but swap token 1 for token 0
    // function testGetPriceSwapToken1() public {
    //     twapFixture();
    //     vm.startPrank(owner);
    //     fraxBPPhoMetapool.exchange(1, 0, twoHundredFiftyThousand_d18, tenThousand_d18);
    //     uint256 expectedNewUSDPHOPrice = _getNewUSDPHOPrice();
    //     vm.expectEmit(true, true, false, true);
    //     emit PriceUpdated(expectedNewUSDPHOPrice, block.timestamp);
    //     phoTwapOracle.getPrice();
    //     assertEq(expectedNewUSDPHOPrice, phoTwapOracle.latestUSDPHOPrice());
    //     assertEq(block.timestamp, phoTwapOracle.blockTimestampLast());
    //     vm.stopPrank();
    // }

    // /// @notice swap PHO for Frax within metapool and check USDPHO price after
    // function testGetPriceSwapUnderlyingPhoFrax() public {
    //     address[8] memory dexPoolIndices = curveFactory.get_underlying_coins(fraxBPPhoMetapoolAddress);
    //     (int128 fromIndexPho, int128 toIndexFrax, bool underlying) = curveFactory.get_coin_indices(fraxBPPhoMetapoolAddress, address(pho), fraxAddress);
    //     twapFixture();
    //     assertEq(underlying, true);

    //     vm.startPrank(owner);
    //     fraxBPPhoMetapool.exchange_underlying(fromIndexPho, toIndexFrax, tenThousand_d18, 0); // TODO - confirm that underlying asset exchanges atomically convert to base tokens through `exchange_underlying()`
        
    //     uint256 expectedNewUSDPHOPrice = _getNewUSDPHOPrice();
    //     vm.expectEmit(true, true, false, true);
    //     emit PriceUpdated(expectedNewUSDPHOPrice, block.timestamp);
    //     phoTwapOracle.getPrice();
    //     assertEq(expectedNewUSDPHOPrice, phoTwapOracle.latestUSDPHOPrice());
    //     assertEq(block.timestamp, phoTwapOracle.blockTimestampLast());
    //     vm.stopPrank();
    // }

    //  /// @notice swap Frax for PHO within metapool and check USDPHO price after
    // function testGetPriceSwapUnderlyingFraxPho() public {
    //     address[8] memory dexPoolIndices = curveFactory.get_underlying_coins(fraxBPPhoMetapoolAddress);
    //     (int128 fromIndexFrax, int128 toIndexPHO, bool underlying) = curveFactory.get_coin_indices(fraxBPPhoMetapoolAddress, address(pho), fraxAddress);
    //     twapFixture();
    //     assertEq(underlying, true);

    //     vm.startPrank(owner);
    //     fraxBPPhoMetapool.exchange_underlying(fromIndexFrax, toIndexPHO, tenThousand_d18, 0); // TODO - confirm that underlying asset exchanges atomically convert to base tokens through `exchange_underlying()`
        
    //     uint256 expectedNewUSDPHOPrice = _getNewUSDPHOPrice();
    //     vm.expectEmit(true, true, false, true);
    //     emit PriceUpdated(expectedNewUSDPHOPrice, block.timestamp);
    //     phoTwapOracle.getPrice();
    //     assertEq(expectedNewUSDPHOPrice, phoTwapOracle.latestUSDPHOPrice());
    //     assertEq(block.timestamp, phoTwapOracle.blockTimestampLast());
    //     vm.stopPrank();        
    // }

    //  /// @notice swap USDC for Frax within metapool and check USDPHO price after
    // function testGetPriceSwapUnderlyingUsdcFrax() public {
    //     address[8] memory dexPoolIndices = curveFactory.get_underlying_coins(fraxBPPhoMetapoolAddress);
    //     (int128 fromIndexUsdc, int128 toIndexFrax, bool underlying) = curveFactory.get_coin_indices(fraxBPPhoMetapoolAddress, USDC_ADDRESS, fraxAddress);
    //     twapFixture();
    //     assertEq(underlying, true);

    //     vm.startPrank(owner);
    //     fraxBPPhoMetapool.exchange_underlying(fromIndexUsdc, toIndexFrax, tenThousand_d6, 0); // TODO - confirm that underlying asset exchanges atomically convert to base tokens through `exchange_underlying()`
        
    //     uint256 expectedNewUSDPHOPrice = _getNewUSDPHOPrice();
    //     vm.expectEmit(true, true, false, true);
    //     emit PriceUpdated(expectedNewUSDPHOPrice, block.timestamp);
    //     phoTwapOracle.getPrice();
    //     assertEq(expectedNewUSDPHOPrice, phoTwapOracle.latestUSDPHOPrice());
    //     assertEq(block.timestamp, phoTwapOracle.blockTimestampLast());
    //     vm.stopPrank();
    // }

    // // TODO - add tests for: checking price when someone adds liquidity, and removes liquidity

    // /// consult() tests

    // function testCannotConsult() public {
    //     twapFixture();
    //     PHOTWAPOracle phoTwapOracle2 = new PHOTWAPOracle(address(pho), metaPoolFactoryAddress, fraxBPPool, fraxBPLPToken, fraxAddress, USDC_ADDRESS, period, fraxBPPhoMetapoolAddress, PRICE_THRESHOLD); // deploy PHOTWAPOracle
    //     vm.expectRevert("PHOTWAPOracle: PHOTWAPOracle not initialized");
    //     phoTwapOracle2.consult(address(fraxBPLP), oneHundred_d18);
    // }

    // function testConsultTokenOneOut() public {
    //     twapFixture();
    //     uint256 token1Out = phoTwapOracle.consult(address(pho), oneHundred_d18);
    //     uint256 expectedToken1Out = (phoTwapOracle.twap[0] * oneHundred_d18) / PHO_PRICE_PRECISION;
    //     assertEq(expectedToken1Out, token1Out);
    // }

    // function testConsultTokenZeroOut() public {
    //     twapFixture();
    //     uint256 token0Out = phoTwapOracle.consult(fraxBPLPToken, oneHundred_d18);
    //     uint256 expectedToken0Out = (phoTwapOracle.twap[1] * oneHundred_d18) / PHO_PRICE_PRECISION;
    //     assertEq(expectedToken0Out, token0Out);
    // }

    // function testCannotConsultInvalidToken() public {
    //     twapFixture();
    //     vm.expectRevert("PHOTWAPOracle: invalid token");
    //     phoTwapOracle.consult(dummyAddress, oneHundred_d18);
    // }

    // /// setPriceSource() tests

    // function testCannotSetPriceSourceAddressZero() public {
    //     twapFixture();
    //     vm.startPrank(owner);
    //     vm.expectRevert("PHOTWAPOracle: zero address detected");
    //     phoTwapOracle.setPriceSource(address(0));
    // }

    // function testCannotSetNonMetapoolPriceSource() public {
    //     twapFixture();
    //     vm.prank(owner);
    //     vm.expectRevert("PHOTWAPOracle: address does not point to a metapool");
    //     phoTwapOracle.setPriceSource(weth);
    // }

    // function testCannotSetNonPhoPriceSource() public {
    //     twapFixture();
    //     vm.prank(owner);
    //     vm.expectRevert("PHOTWAPOracle: $PHO is not present in the metapool");
    //     phoTwapOracle.setPriceSource(fraxBPLUSD);
    // }

    // /// @notice replace old price source (fraxBPPhoMetapool) with a new one
    // function testPriceSource() public {
    //     address newSource = _deployFraxBPPHOPool();
    //     vm.expectEmit(true, false, false, true);
    //     emit PriceSourceUpdated(newSource);
    //     vm.prank(owner);
    //     phoTwapOracle.setPriceSource(newSource);
    // }

    // /// setPriceUpdateThreshold() tests

    // function testCannotSetPriceThreshold() public {
    //     vm.startPrank(owner);
    //     vm.expectRevert("PHOTWAPOracle: invalid priceUpdateThreshold value");
    //     phoTwapOracle.setPriceUpdateThreshold(1000001);
    //     vm.expectRevert("PHOTWAPOracle: invalid priceUpdateThreshold value");
    //     phoTwapOracle.setPriceUpdateThreshold(0);
    //     vm.stopPrank();
    // }

    // function testSetPriceUpdateThreshold() public {
    //     vm.startPrank(owner);
    //     vm.expectEmit(true, false, false, true);
    //     emit PriceUpdateThresholdChanged(999999);
    //     phoTwapOracle.setPriceUpdateThreshold(999999);
    //     assertEq(phoTwapOracle.priceUpdateThreshold(), 999999);
    //     vm.stopPrank();
    // }

    /// Helpers

    /// @notice carry out initial call for `getPrice()`, fast forward one period
    function twapFixture() public {
        _fundAndApproveFRAX(owner, fraxBPPhoMetapoolAddress, one_m_d18, 0);
        vm.startPrank(owner);
        phoTwapOracle.getPrice(); 
        vm.warp(phoTwapOracle.latestBlockTimestamp() + period + 1);
        // pho.approve(address(fraxBPPhoMetapool), six_m_d18);
        // fraxBPLP.approve(address(fraxBPPhoMetapool), six_m_d18);
        vm.stopPrank();
    }

    /// @notice manual helper (similar to helper in PHOTWAPOracle.sol except with test vars)
    /// @return newest USD/FraxBP (scaled by d18) price answer derived from fraxBP balances and USD/Frax && USD/USDC priceFeeds
    function _getUSDPerFraxBP() internal returns(uint256) {
        uint256 fraxInFraxBP = fraxBP.balances(0); // FRAX - decimals: 18
        uint256 usdcInFraxBP = fraxBP.balances(1); // USDC - decimals: 6
        uint256 fraxPerFraxBP = fraxInFraxBP * PHO_PRICE_PRECISION / fraxBPLP.totalSupply(); // UNITS: (FRAX/FraxBP) - scaled by d18
        uint256 usdcPerFraxBP = usdcInFraxBP * PHO_PRICE_PRECISION * missing_decimals / fraxBPLP.totalSupply(); // UNITS: (USDC/FraxBP) - scaled by d18
        uint256 usdPerFraxBP = (((fraxPerFraxBP * PHO_PRICE_PRECISION / priceFeed.getPrice(fraxAddress))) + (usdcPerFraxBP * PHO_PRICE_PRECISION / priceFeed.getPrice(USDC_ADDRESS))); // UNITS: (USD/FraxBP) - scaled by d18
        return usdPerFraxBP;
    }

    /// @notice manual helper calc to compare against calcs within tested contract
    /// @return new expectedPHOUSDPrice
    /// NOTE - this is called after oracle is initialized with 1m PHO && 1m FraxBP genesis liquidity
    /// NOTE - This helper does not care if price is above PRICE_THRESHOLD. It shouldn't be though, as there are separate tests checking for that requirement.
    function _getNewUSDPHOPrice() internal returns(uint256) {
        uint256 token0balance = fraxBPPhoMetapool.balances(0);
        uint256 token1balance = fraxBPPhoMetapool.balances(1);
        uint256 token0Price = token1balance * PRICE_PRECISION / token0balance;
        uint256 token1Price = token0balance * PRICE_PRECISION / token1balance;

        uint256 expectedPeriodTimeElapsed = block.timestamp - phoTwapOracle.latestBlockTimestamp();
        uint256[2] memory expectedPriceCumulativeNew;
        expectedPriceCumulativeNew[0] = ((token0Price) * expectedPeriodTimeElapsed * PHO_PRICE_PRECISION);
        expectedPriceCumulativeNew[1] = ((token1Price) * expectedPeriodTimeElapsed * PHO_PRICE_PRECISION);
        uint256[2] memory lastTwap = [phoTwapOracle.twap(0), phoTwapOracle.twap(1)];
        uint256[2] memory expectedTwap;
        uint256[2] memory priceCumulativeLast = [phoTwapOracle.priceCumulativeLast(0), phoTwapOracle.priceCumulativeLast(1)];

        for(uint256 i = 0; i < 2; i++ ) {
            console.log("CHECK: PriceCumNew: %s, PriceCumLast: %s, PeriodTimeElapsed: %s",expectedPriceCumulativeNew[i], priceCumulativeLast[i], expectedPeriodTimeElapsed);
            expectedTwap[i] = (expectedPriceCumulativeNew[i] - priceCumulativeLast[i]) / expectedPeriodTimeElapsed;
            // console.log("twap: %s", expectedTwap[i] / PHO_PRICE_PRECISION);
            // console log each thing here and see if the divisor is smaller than the numerator.
        } // want twap[0], the price FraxBP/PHO, we keep the other just in case
 
        // uint256 expectedLatestUSDPHOPrice = 1;
        uint256 expectedLatestUSDPHOPrice = (expectedTwap[0] * _getUSDPerFraxBP()) / PHO_PRICE_PRECISION; //  UNITS: (USD/PHO) = (FraxBP/PHO * USD/FraxBP) - decimals d18
        return expectedLatestUSDPHOPrice;
    }
}
