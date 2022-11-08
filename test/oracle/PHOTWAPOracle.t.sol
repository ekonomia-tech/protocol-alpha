// // SPDX-License-Identifier: GPL-3.0-or-later
// pragma solidity ^0.8.13;

// import "../BaseSetup.t.sol";
// import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "@protocol/contracts/PHO.sol";
// import "@external/curve/ICurvePool.sol";
// import "@external/curve/ICurveFactory.sol";
// import "@oracle/PHOTWAPOracle.sol";

// /// @notice Basic tests assessing genesis PHOTWAPOracle
// /// @dev For function sigs in metapool, see an example here https://etherscan.io/address/0x497CE58F34605B9944E6b15EcafE6b001206fd25#code
// /// TODO - Write exhaustive tests ensuring this oracle is robust
// contract PHOTWAPOracleTest is BaseSetup {
//     ICurvePool public curvePool;
//     address public fraxBPPhoMetapoolAddress;
//     PHOTWAPOracle public phoTwapOracle;

//     event PriceUpdated(uint256 indexed latestPHOUSDPrice, uint256 indexed blockTimestampLast);
//     event PriceUpdateThresholdChanged(uint256 priceUpdateThreshold);

//     /// @notice setup PHOTWAPOracle with 1 million PHO && 1 million FraxBP (33% USDC, 33% FRAX, 33% PHO) or (66% FraxBP, and 33% PHO)
//     function setUp() public {
//         vm.startPrank(owner);
//         // set base pricefeeds needed for PHOTWAPOracle
//         priceFeed.addFeed(FRAX_ADDRESS, PRICEFEED_FRAXUSD); // https://data.chain.link/ethereum/mainnet/stablecoins/frax-usd
//         priceFeed.addFeed(USDC_ADDRESS, PRICEFEED_USDCUSD); // https://data.chain.link/ethereum/mainnet/stablecoins/usdc-usd
//         priceFeed.addFeed(ETH_NULL_ADDRESS, PRICEFEED_ETHUSD); // https://data.chain.link/ethereum/mainnet/crypto-usd/eth-usd
//         vm.stopPrank();

//         fraxBPPhoMetapoolAddress = (_deployFraxBPPHOPool()); // deploy FRAXBP-PHO metapool

//         vm.prank(address(kernel));
//         pho.mint(owner, ONE_MILLION_D18 * 5);

//         _fundAndApproveUSDC(owner, address(fraxBP), ONE_MILLION_D6 * 2, ONE_MILLION_D6 * 2);
//         _fundAndApproveFRAX(owner, address(fraxBP), ONE_MILLION_D18 * 2, ONE_MILLION_D18 * 2);

//         vm.startPrank(owner);
//         uint256[2] memory fraxBPmetaLiquidity;
//         fraxBPmetaLiquidity[0] = ONE_MILLION_D18 * 2; // frax
//         fraxBPmetaLiquidity[1] = ONE_MILLION_D6 * 2; // usdc

//         fraxBP.add_liquidity(fraxBPmetaLiquidity, 0);

//         pho.approve(address(fraxBPPhoMetapool), ONE_MILLION_D18 * 5);
//         fraxBPLP.approve(address(fraxBPPhoMetapool), ONE_MILLION_D18 * 5);
//         uint256[2] memory metaLiquidity;
//         metaLiquidity[0] = ONE_MILLION_D18;
//         metaLiquidity[1] = ONE_MILLION_D18;
//         fraxBPPhoMetapool.add_liquidity(metaLiquidity, 0); // FraxBP-PHO metapool now at 66/33 split, respectively. Meaning 33/33/33 for underlying assets: USDC/Frax/PHO

//         phoTwapOracle =
//         new PHOTWAPOracle(address(pho), FRAXBP_POOL, FRAXBP_LP_TOKEN, FRAX_ADDRESS, USDC_ADDRESS, address(priceFeed), period, fraxBPPhoMetapoolAddress, PRICE_THRESHOLD); // deploy PHOTWAPOracle
//         fraxBPPhoMetapool = phoTwapOracle.dexPool();
//         pho.approve(fraxBPPhoMetapoolAddress, ONE_HUNDRED_THOUSAND_D18 * 5);
//         fraxBPLP.approve(fraxBPPhoMetapoolAddress, ONE_HUNDRED_THOUSAND_D18 * 5);
//         usdc.approve(fraxBPPhoMetapoolAddress, ONE_MILLION_D6);

//         vm.stopPrank();
//     }

//     /// constructor() tests

//     /// @notice test constructor setup
//     function testPHOTWAPOracleConstructor() public {
//         assertEq(address(phoTwapOracle.pho()), address(pho));
//         assertEq(address(phoTwapOracle.fraxBPPool()), FRAXBP_POOL);
//         assertEq(address(phoTwapOracle.fraxBPLP()), FRAXBP_LP_TOKEN);
//         assertEq(phoTwapOracle.fraxAddress(), FRAX_ADDRESS);
//         assertEq(phoTwapOracle.usdcAddress(), USDC_ADDRESS);
//         assertEq(address(phoTwapOracle.priceFeeds()), address(priceFeed));
//         assertEq(phoTwapOracle.period(), period);
//         assertEq(address(phoTwapOracle.dexPool()), fraxBPPhoMetapoolAddress);
//         assertEq(phoTwapOracle.priceUpdateThreshold(), PRICE_THRESHOLD);
//         assertEq(phoTwapOracle.initOracle(), false);
//         assertEq(0, phoTwapOracle.latestBlockTimestamp());
//     }

//     /// updatePrice() tests

//     /// @notice test newPHOUSDPrice against manual calculations with genesis liquidity
//     function testInitialUpdatePrice() public {
//         uint256 expectedPeriodTimeElapsed = block.timestamp;
//         uint256 expectedTWAP0 = fraxBPLP.balanceOf(fraxBPPhoMetapoolAddress) * PHO_PRICE_PRECISION
//             / pho.balanceOf(fraxBPPhoMetapoolAddress);
//         uint256 expectedTWAP1 = pho.balanceOf(fraxBPPhoMetapoolAddress) * PHO_PRICE_PRECISION
//             / fraxBPLP.balanceOf(fraxBPPhoMetapoolAddress);
//         uint256 expectedBlockTimeStamp = block.timestamp;
//         uint256 expectedPriceCumulativeLast0 = expectedTWAP0;
//         uint256 expectedPriceCumulativeLast1 = expectedTWAP1;
//         uint256 expectedNewUSDPHOPrice = expectedTWAP0 * _getUSDPerFraxBP() / PHO_PRICE_PRECISION;

//         assertEq(expectedPeriodTimeElapsed, block.timestamp - phoTwapOracle.latestBlockTimestamp()); //latestBlockTimestamp should be zero

//         vm.expectEmit(true, true, false, true);
//         emit PriceUpdated(expectedNewUSDPHOPrice, expectedBlockTimeStamp);
//         phoTwapOracle.updatePrice();

//         assertEq(expectedNewUSDPHOPrice, phoTwapOracle.latestUSDPHOPrice());
//         assertEq(phoTwapOracle.initOracle(), true);
//         assertEq(expectedPriceCumulativeLast0, phoTwapOracle.priceCumulativeLast0());
//         assertEq(expectedPriceCumulativeLast1, phoTwapOracle.priceCumulativeLast1());
//         assertEq(expectedBlockTimeStamp, phoTwapOracle.latestBlockTimestamp());
//         assertEq(expectedTWAP0, phoTwapOracle.twap0());
//         assertEq(expectedTWAP1, phoTwapOracle.twap1());
//     }

//     /// @notice test revert in updatePrice() after doing the first significant swap in the metapool where a user swaps token 0 for token 1 but with high price effects
//     function testCannotUpdatePricePastThreshold() public {
//         twapFixture();
//         uint256 oldUSDPHOPrice = phoTwapOracle.latestUSDPHOPrice();
//         vm.startPrank(owner);
//         fraxBPPhoMetapool.exchange(0, 1, TEN_THOUSAND_D18 * 25, 0);
//         phoTwapOracle.updatePrice();
//         assertEq(oldUSDPHOPrice, phoTwapOracle.latestUSDPHOPrice());
//         vm.stopPrank();
//     }

//     /// @notice test updatePrice() after doing swapping of token 0 for token 1
//     function testUpdatePriceSwapToken0() public {
//         twapFixture(); // updatePrice() called for first time, and we've fast forwarded 1 period
//         vm.startPrank(owner);
//         fraxBPPhoMetapool.exchange(0, 1, TEN_THOUSAND_D18, 0);
//         uint256 expectedNewUSDPHOPrice = _getNewUSDPHOPrice();
//         vm.expectEmit(true, true, false, true);
//         emit PriceUpdated(expectedNewUSDPHOPrice, block.timestamp);
//         phoTwapOracle.updatePrice();
//         assertEq(expectedNewUSDPHOPrice, phoTwapOracle.latestUSDPHOPrice());
//         assertEq(block.timestamp, phoTwapOracle.latestBlockTimestamp());
//         vm.stopPrank();
//     }

//     /// @notice test updatePrice() after doing swapping of token 1 for token 0
//     function testUpdatePriceSwapToken1() public {
//         twapFixture();
//         vm.startPrank(owner);
//         fraxBPPhoMetapool.exchange(1, 0, TEN_THOUSAND_D18, 0);
//         uint256 expectedNewUSDPHOPrice = _getNewUSDPHOPrice();
//         vm.expectEmit(true, true, false, true);
//         emit PriceUpdated(expectedNewUSDPHOPrice, block.timestamp);
//         phoTwapOracle.updatePrice();
//         assertEq(expectedNewUSDPHOPrice, phoTwapOracle.latestUSDPHOPrice());
//         assertEq(block.timestamp, phoTwapOracle.latestBlockTimestamp());
//         vm.stopPrank();
//     }

//     /// @notice test updatePrice() after doing swapping of underlying tokens PHO for FRAX
//     function testUpdatePriceSwapUnderlyingPhoFrax() public {
//         (int128 fromIndexPho, int128 toIndexFrax, bool underlying) =
//             curveFactory.get_coin_indices(fraxBPPhoMetapoolAddress, address(pho), FRAX_ADDRESS);
//         twapFixture();
//         assertEq(underlying, true);

//         vm.startPrank(owner);
//         fraxBPPhoMetapool.exchange_underlying(fromIndexPho, toIndexFrax, TEN_THOUSAND_D18, 0); // TODO - confirm that underlying asset exchanges atomically convert to base tokens through `exchange_underlying()`

//         uint256 expectedNewUSDPHOPrice = _getNewUSDPHOPrice();
//         vm.expectEmit(true, true, false, true);
//         emit PriceUpdated(expectedNewUSDPHOPrice, block.timestamp);
//         phoTwapOracle.updatePrice();
//         assertEq(expectedNewUSDPHOPrice, phoTwapOracle.latestUSDPHOPrice());
//         assertEq(block.timestamp, phoTwapOracle.latestBlockTimestamp());
//         vm.stopPrank();
//     }

//     /// @notice test updatePrice() after doing swapping of underlying tokens FRAX for PHO
//     function testUpdatePriceSwapUnderlyingFraxPho() public {
//         (int128 fromIndexFrax, int128 toIndexPHO, bool underlying) =
//             curveFactory.get_coin_indices(fraxBPPhoMetapoolAddress, address(pho), FRAX_ADDRESS);
//         twapFixture();
//         assertEq(underlying, true);

//         vm.startPrank(owner);
//         fraxBPPhoMetapool.exchange_underlying(fromIndexFrax, toIndexPHO, TEN_THOUSAND_D18, 0); // TODO - confirm that underlying asset exchanges atomically convert to base tokens through `exchange_underlying()`

//         uint256 expectedNewUSDPHOPrice = _getNewUSDPHOPrice();
//         vm.expectEmit(true, true, false, true);
//         emit PriceUpdated(expectedNewUSDPHOPrice, block.timestamp);
//         phoTwapOracle.updatePrice();
//         assertEq(expectedNewUSDPHOPrice, phoTwapOracle.latestUSDPHOPrice());
//         assertEq(block.timestamp, phoTwapOracle.latestBlockTimestamp());
//         vm.stopPrank();
//     }

//     /// @notice test updatePrice() after doing swapping of underlying tokens USDC for FRAX
//     function testUpdatePriceSwapUnderlyingUsdcFrax() public {
//         (int128 fromIndexUsdc, int128 toIndexFrax, bool underlying) =
//             curveFactory.get_coin_indices(fraxBPPhoMetapoolAddress, USDC_ADDRESS, FRAX_ADDRESS);
//         twapFixture();
//         assertEq(underlying, true);

//         vm.startPrank(owner);
//         fraxBPPhoMetapool.exchange_underlying(fromIndexUsdc, toIndexFrax, TEN_THOUSAND_D6, 0); // TODO - confirm that underlying asset exchanges atomically convert to base tokens through `exchange_underlying()`

//         uint256 expectedNewUSDPHOPrice = _getNewUSDPHOPrice();
//         vm.expectEmit(true, true, false, true);
//         emit PriceUpdated(expectedNewUSDPHOPrice, block.timestamp);
//         phoTwapOracle.updatePrice();
//         assertEq(expectedNewUSDPHOPrice, phoTwapOracle.latestUSDPHOPrice());
//         assertEq(block.timestamp, phoTwapOracle.latestBlockTimestamp());
//         vm.stopPrank();
//     }

//     /// updatePrice() tests when adding or removing liquidity from metapool
//     /// NOTE - for all liquidity changing tests, I'd like to talk with ppl on how the prices would be anticipated to be changed.

//     /// @notice test updatePrice() after genesis && liquidity increased at ratio of pool (33.33%PHO / 66.66% FRAXBP)
//     function testUpdatePriceAddLiquidity() public {
//         twapFixture();
//         vm.startPrank(owner);
//         uint256[2] memory metaLiquidity;
//         metaLiquidity[0] = TEN_THOUSAND_D18 * 25;
//         metaLiquidity[1] = TEN_THOUSAND_D18 * 25;
//         fraxBPPhoMetapool.add_liquidity(metaLiquidity, 0);
//         uint256 expectedNewUSDPHOPrice = _getNewUSDPHOPrice();
//         uint256 oldUSDPHOPrice = phoTwapOracle.latestUSDPHOPrice();
//         vm.expectEmit(true, true, false, true);
//         emit PriceUpdated(expectedNewUSDPHOPrice, block.timestamp);
//         phoTwapOracle.updatePrice();
//         uint256 newUSDPHOPrice = phoTwapOracle.latestUSDPHOPrice();
//         assertEq(expectedNewUSDPHOPrice, newUSDPHOPrice);
//         assertEq(oldUSDPHOPrice != newUSDPHOPrice, true);
//         vm.stopPrank();
//     }

//     /// @notice test updatePrice() after genesis && liquidity removed at pool ratio
//     function testUpdatePriceRemoveLiquidity() public {
//         twapFixture();
//         vm.startPrank(owner);
//         uint256[2] memory minAmounts = [uint256(0), uint256(0)];
//         fraxBPPhoMetapool.remove_liquidity(
//             fraxBPPhoMetapool.balanceOf(owner) / 2, minAmounts, owner
//         );
//         uint256 expectedNewUSDPHOPrice = _getNewUSDPHOPrice();
//         uint256 oldUSDPHOPrice = phoTwapOracle.latestUSDPHOPrice();
//         vm.expectEmit(true, true, false, true);
//         emit PriceUpdated(expectedNewUSDPHOPrice, block.timestamp);
//         phoTwapOracle.updatePrice();
//         uint256 newUSDPHOPrice = phoTwapOracle.latestUSDPHOPrice();
//         assertEq(expectedNewUSDPHOPrice, newUSDPHOPrice);
//         assertEq(oldUSDPHOPrice != newUSDPHOPrice, true);
//         vm.stopPrank();
//     }

//     /// @notice test reversion in updatePrice() when no liquidity in metapool
//     function testCannotUpdatePrice() public {
//         vm.startPrank(owner);
//         uint256[2] memory min_amounts = [uint256(0), uint256(0)];
//         fraxBPPhoMetapool.remove_liquidity(fraxBPPhoMetapool.balanceOf(owner), min_amounts, owner); // remove all liquidity
//         vm.expectRevert("PHOTWAPOracle: metapool balance(s) cannot be 0");
//         phoTwapOracle.updatePrice();
//         vm.stopPrank();
//     }

//     /// setPriceUpdateThreshold() tests

//     /// @notice test setPriceUpdateThreshold() reverts when param is higher than allowed MAX_PRICE_THRESHOLD
//     function testCannotSetPriceThreshold() public {
//         vm.startPrank(owner);
//         vm.expectRevert("PHOTWAPOracle: invalid priceUpdateThreshold value");
//         phoTwapOracle.setPriceUpdateThreshold(1000001);
//         vm.expectRevert("PHOTWAPOracle: invalid priceUpdateThreshold value");
//         phoTwapOracle.setPriceUpdateThreshold(0);
//         vm.stopPrank();
//     }

//     /// @notice tests basic setPriceUpdateThreshold() functionality
//     function testSetPriceUpdateThreshold() public {
//         vm.startPrank(owner);
//         vm.expectEmit(true, false, false, true);
//         emit PriceUpdateThresholdChanged(999999);
//         phoTwapOracle.setPriceUpdateThreshold(999999);
//         assertEq(phoTwapOracle.priceUpdateThreshold(), 999999);
//         vm.stopPrank();
//     }

//     /// helpers

//     /// @notice carry out initial call for `updatePrice()`, fast forward one period
//     function twapFixture() public {
//         _fundAndApproveFRAX(owner, fraxBPPhoMetapoolAddress, ONE_HUNDRED_THOUSAND_D18 * 5, 0);
//         vm.startPrank(owner);
//         phoTwapOracle.updatePrice();
//         vm.warp(phoTwapOracle.latestBlockTimestamp() + period + 1);
//         vm.stopPrank();
//     }

//     /// @notice manual helper (similar to helper in PHOTWAPOracle.sol except with test vars)
//     /// @return newest USD/FraxBP (normalized by d18) price answer derived from fraxBP balances and USD/Frax && USD/USDC priceFeeds
//     function _getUSDPerFraxBP() internal returns (uint256) {
//         uint256 fraxInFraxBP = fraxBP.balances(0); // FRAX - decimals: 18
//         uint256 usdcInFraxBP = fraxBP.balances(1); // USDC - decimals: 6
//         uint256 fraxBPLPTotal = fraxBPLP.totalSupply();
//         uint256 fraxPerFraxBP = fraxInFraxBP * PHO_PRICE_PRECISION / fraxBPLPTotal; // UNITS: (FRAX/FraxBP) - normalized by d18
//         uint256 usdcPerFraxBP =
//             usdcInFraxBP * PHO_PRICE_PRECISION * DECIMALS_DIFFERENCE / fraxBPLPTotal; // UNITS: (USDC/FraxBP) - normalized by d18
//         uint256 usdPerFraxBP = (
//             ((fraxPerFraxBP * PHO_PRICE_PRECISION / priceFeed.getPrice(FRAX_ADDRESS)))
//                 + (usdcPerFraxBP * PHO_PRICE_PRECISION / priceFeed.getPrice(USDC_ADDRESS))
//         ); // UNITS: (USD/FraxBP) - normalized by d18
//         return usdPerFraxBP;
//     }

//     /// @notice manual helper calc to compare against calcs within tested contract
//     /// @return new expectedPHOUSDPrice
//     /// NOTE - this is called after oracle is initialized with 1m PHO && 1m FraxBP genesis liquidity
//     function _getNewUSDPHOPrice() internal returns (uint256) {
//         uint256 token0balance = fraxBPPhoMetapool.balances(0);
//         uint256 token1balance = fraxBPPhoMetapool.balances(1);
//         uint256 token0Price = token1balance * PHO_PRICE_PRECISION / token0balance;
//         uint256 token1Price = token0balance * PHO_PRICE_PRECISION / token1balance;

//         uint256 expectedPeriodTimeElapsed = block.timestamp - phoTwapOracle.latestBlockTimestamp();
//         uint256 expectedPriceCumulativeNew0 = ((token0Price) * expectedPeriodTimeElapsed);
//         uint256 expectedPriceCumulativeNew1 = ((token1Price) * expectedPeriodTimeElapsed);
//         (uint256 priceCumulativeLast0, uint256 priceCumulativeLast1) =
//             (phoTwapOracle.priceCumulativeLast0(), phoTwapOracle.priceCumulativeLast1());
//         uint256 expectedTwap0 =
//             (expectedPriceCumulativeNew0 - priceCumulativeLast0) / expectedPeriodTimeElapsed;
//         uint256 expectedTwap1 =
//             (expectedPriceCumulativeNew1 - priceCumulativeLast1) / expectedPeriodTimeElapsed; // we want the expectedTwap0 FraxBP/PHO, we keep the other just in case

//         uint256 expectedLatestUSDPHOPrice =
//             (expectedTwap0 * _getUSDPerFraxBP()) / PHO_PRICE_PRECISION; //  UNITS: (USD/PHO) = (FraxBP/PHO * USD/FraxBP) - decimals d18
//         return expectedLatestUSDPHOPrice;
//     }
// }
