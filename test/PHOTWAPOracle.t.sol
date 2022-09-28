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

/// @notice basic tests assessing genesis PHOTWAPOracle
/// @dev for function sigs in metapool, see an example here https://etherscan.io/address/0x497CE58F34605B9944E6b15EcafE6b001206fd25#code
contract PHOTWAPOracleTest is BaseSetup {
    ICurvePool public curvePool;
    address public fraxBPPhoMetapoolAddress;
    PHOTWAPOracle public phoTwapOracle;

    event PriceUpdated(uint256 indexed latestPHOUSDPrice, uint256 indexed blockTimestampLast);
    event PriceSourceUpdated(address indexed priceSource);
    event PriceUpdateThresholdChanged(uint256 priceUpdateThreshold);
    event PriceThresholdExceeded(bool priceThresholdChangeExceeded);

    /// @notice setup PHOTWAPOracle with 1 million PHO && 1 million FraxBP (33% USDC, 33% FRAX, 33% PHO) or (66% FraxBP, and 33% PHO)
    function setUp() public {
        vm.startPrank(owner);
        // set base pricefeeds needed for PHOTWAPOracle
        priceFeed.addFeed(fraxAddress, PriceFeed_FRAXUSD); // https://data.chain.link/ethereum/mainnet/stablecoins/frax-usd
        priceFeed.addFeed(USDC_ADDRESS, PriceFeed_USDCUSD); // https://data.chain.link/ethereum/mainnet/stablecoins/usdc-usd
        priceFeed.addFeed(ethNullAddress, PriceFeed_ETHUSD); // https://data.chain.link/ethereum/mainnet/crypto-usd/eth-usd
        vm.stopPrank();

        fraxBPPhoMetapoolAddress = (_deployFraxBPPHOPool()); // deploy FRAXBP-PHO metapool

        vm.prank(address(teller));
        pho.mint(owner, five_m_d18);

        _fundAndApproveUSDC(owner, address(fraxBP), two_m_d6, two_m_d6);
        _fundAndApproveFRAX(owner, address(fraxBP), two_m_d18, two_m_d18);

        vm.startPrank(owner);
        uint256[2] memory fraxBPmetaLiquidity;
        fraxBPmetaLiquidity[0] = two_m_d18; // frax
        fraxBPmetaLiquidity[1] = two_m_d6; // usdc

        fraxBP.add_liquidity(fraxBPmetaLiquidity, 0);

        pho.approve(address(fraxBPPhoMetapool), five_m_d18);
        fraxBPLP.approve(address(fraxBPPhoMetapool), five_m_d18);
        uint256[2] memory metaLiquidity;
        metaLiquidity[0] = one_m_d18;
        metaLiquidity[1] = one_m_d18;
        fraxBPPhoMetapool.add_liquidity(metaLiquidity, 0); // FraxBP-PHO metapool now at 66/33 split, respectively. Meaning 33/33/33 for underlying assets: USDC/Frax/PHO

        phoTwapOracle =
        new PHOTWAPOracle(address(pho), metaPoolFactoryAddress, fraxBPPool, fraxBPLPToken, fraxAddress, USDC_ADDRESS, address(priceFeed), period, fraxBPPhoMetapoolAddress, PRICE_THRESHOLD); // deploy PHOTWAPOracle
        fraxBPPhoMetapool = phoTwapOracle.dexPool();
        pho.approve(fraxBPPhoMetapoolAddress, fiveHundredThousand_d18);
        fraxBPLP.approve(fraxBPPhoMetapoolAddress, fiveHundredThousand_d18);
        usdc.approve(fraxBPPhoMetapoolAddress, one_m_d6);

        vm.stopPrank();
    }

    /// constructor() tests

    /// @notice test constructor setup
    function testPHOTWAPOracleConstructor() public {
        address phoTwapToken0 = phoTwapOracle.tokens(0);
        address phoTwapToken1 = phoTwapOracle.tokens(1);

        assertEq(address(phoTwapOracle.pho()), address(pho));
        assertEq(address(phoTwapOracle.curveFactory()), metaPoolFactoryAddress);
        assertEq(address(phoTwapOracle.fraxBPPool()), fraxBPPool);
        assertEq(address(phoTwapOracle.fraxBPLP()), fraxBPLPToken);
        assertEq(phoTwapOracle.fraxAddress(), fraxAddress);
        assertEq(phoTwapOracle.usdcAddress(), USDC_ADDRESS);
        assertEq(address(phoTwapOracle.priceFeeds()), address(priceFeed));
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

    /// getPrice() tests

    /// @notice test newPHOUSDPrice against manual calculations with genesis liquidity
    function testInitialGetPrice() public {
        uint256 expectedPeriodTimeElapsed = block.timestamp;
        uint256 expectedTWAP0 = fraxBPLP.balanceOf(fraxBPPhoMetapoolAddress) * PHO_PRICE_PRECISION
            / pho.balanceOf(fraxBPPhoMetapoolAddress);
        uint256 expectedTWAP1 = pho.balanceOf(fraxBPPhoMetapoolAddress) * PHO_PRICE_PRECISION
            / fraxBPLP.balanceOf(fraxBPPhoMetapoolAddress);
        uint256 expectedBlockTimeStamp = block.timestamp;
        uint256 expectedPriceCumulativeLast0 = expectedTWAP0;
        uint256 expectedPriceCumulativeLast1 = expectedTWAP1;
        uint256 expectedNewUSDPHOPrice = expectedTWAP0 * _getUSDPerFraxBP() / PHO_PRICE_PRECISION;

        assertEq(expectedPeriodTimeElapsed, block.timestamp - phoTwapOracle.latestBlockTimestamp()); //latestBlockTimestamp should be zero

        vm.expectEmit(true, true, false, true);
        emit PriceUpdated(expectedNewUSDPHOPrice, expectedBlockTimeStamp);
        phoTwapOracle.getPrice();

        assertEq(expectedNewUSDPHOPrice, phoTwapOracle.latestUSDPHOPrice());
        assertEq(phoTwapOracle.initOracle(), true);
        assertEq(expectedPriceCumulativeLast0, phoTwapOracle.priceCumulativeLast(0));
        assertEq(expectedPriceCumulativeLast1, phoTwapOracle.priceCumulativeLast(1));
        assertEq(expectedBlockTimeStamp, phoTwapOracle.latestBlockTimestamp());
        assertEq(expectedTWAP0, phoTwapOracle.twap(0));
        assertEq(expectedTWAP1, phoTwapOracle.twap(1));
    }

    /// @notice test revert in getPrice() after doing the first significant swap in the metapool where a user swaps token 0 for token 1 but with high price effects
    function testCannotGetPricePastThreshold() public {
        twapFixture();
        uint256 oldUSDPHOPrice = phoTwapOracle.latestUSDPHOPrice();
        vm.startPrank(owner);
        fraxBPPhoMetapool.exchange(0, 1, twoHundredFiftyThousand_d18, 0);
        vm.expectEmit(false, false, false, true);
        emit PriceThresholdExceeded(true);
        phoTwapOracle.getPrice();
        assertEq(oldUSDPHOPrice, phoTwapOracle.latestUSDPHOPrice());
        vm.stopPrank();
    }

    /// @notice test getPrice() after doing swapping of token 0 for token 1
    function testGetPriceSwapToken0() public {
        twapFixture(); // getPrice() called for first time, and we've fast forwarded 1 period
        vm.startPrank(owner);
        fraxBPPhoMetapool.exchange(0, 1, tenThousand_d18, 0);
        uint256 expectedNewUSDPHOPrice = _getNewUSDPHOPrice();
        vm.expectEmit(true, true, false, true);
        emit PriceUpdated(expectedNewUSDPHOPrice, block.timestamp);
        phoTwapOracle.getPrice();
        assertEq(expectedNewUSDPHOPrice, phoTwapOracle.latestUSDPHOPrice());
        assertEq(block.timestamp, phoTwapOracle.latestBlockTimestamp());
        vm.stopPrank();
    }

    /// @notice test getPrice() after doing swapping of token 1 for token 0
    function testGetPriceSwapToken1() public {
        twapFixture();
        vm.startPrank(owner);
        fraxBPPhoMetapool.exchange(1, 0, tenThousand_d18, 0);
        uint256 expectedNewUSDPHOPrice = _getNewUSDPHOPrice();
        vm.expectEmit(true, true, false, true);
        emit PriceUpdated(expectedNewUSDPHOPrice, block.timestamp);
        phoTwapOracle.getPrice();
        assertEq(expectedNewUSDPHOPrice, phoTwapOracle.latestUSDPHOPrice());
        assertEq(block.timestamp, phoTwapOracle.latestBlockTimestamp());
        vm.stopPrank();
    }

    /// @notice test getPrice() after doing swapping of underlying tokens PHO for FRAX
    function testGetPriceSwapUnderlyingPhoFrax() public {
        (int128 fromIndexPho, int128 toIndexFrax, bool underlying) =
            curveFactory.get_coin_indices(fraxBPPhoMetapoolAddress, address(pho), fraxAddress);
        twapFixture();
        assertEq(underlying, true);

        vm.startPrank(owner);
        fraxBPPhoMetapool.exchange_underlying(fromIndexPho, toIndexFrax, tenThousand_d18, 0); // TODO - confirm that underlying asset exchanges atomically convert to base tokens through `exchange_underlying()`

        uint256 expectedNewUSDPHOPrice = _getNewUSDPHOPrice();
        vm.expectEmit(true, true, false, true);
        emit PriceUpdated(expectedNewUSDPHOPrice, block.timestamp);
        phoTwapOracle.getPrice();
        assertEq(expectedNewUSDPHOPrice, phoTwapOracle.latestUSDPHOPrice());
        assertEq(block.timestamp, phoTwapOracle.latestBlockTimestamp());
        vm.stopPrank();
    }

    /// @notice test getPrice() after doing swapping of underlying tokens FRAX for PHO
    function testGetPriceSwapUnderlyingFraxPho() public {
        (int128 fromIndexFrax, int128 toIndexPHO, bool underlying) =
            curveFactory.get_coin_indices(fraxBPPhoMetapoolAddress, address(pho), fraxAddress);
        twapFixture();
        assertEq(underlying, true);

        vm.startPrank(owner);
        fraxBPPhoMetapool.exchange_underlying(fromIndexFrax, toIndexPHO, tenThousand_d18, 0); // TODO - confirm that underlying asset exchanges atomically convert to base tokens through `exchange_underlying()`

        uint256 expectedNewUSDPHOPrice = _getNewUSDPHOPrice();
        vm.expectEmit(true, true, false, true);
        emit PriceUpdated(expectedNewUSDPHOPrice, block.timestamp);
        phoTwapOracle.getPrice();
        assertEq(expectedNewUSDPHOPrice, phoTwapOracle.latestUSDPHOPrice());
        assertEq(block.timestamp, phoTwapOracle.latestBlockTimestamp());
        vm.stopPrank();
    }

    /// @notice test getPrice() after doing swapping of underlying tokens USDC for FRAX
    function testGetPriceSwapUnderlyingUsdcFrax() public {
        (int128 fromIndexUsdc, int128 toIndexFrax, bool underlying) =
            curveFactory.get_coin_indices(fraxBPPhoMetapoolAddress, USDC_ADDRESS, fraxAddress);
        twapFixture();
        assertEq(underlying, true);

        vm.startPrank(owner);
        fraxBPPhoMetapool.exchange_underlying(fromIndexUsdc, toIndexFrax, tenThousand_d6, 0); // TODO - confirm that underlying asset exchanges atomically convert to base tokens through `exchange_underlying()`

        uint256 expectedNewUSDPHOPrice = _getNewUSDPHOPrice();
        vm.expectEmit(true, true, false, true);
        emit PriceUpdated(expectedNewUSDPHOPrice, block.timestamp);
        phoTwapOracle.getPrice();
        assertEq(expectedNewUSDPHOPrice, phoTwapOracle.latestUSDPHOPrice());
        assertEq(block.timestamp, phoTwapOracle.latestBlockTimestamp());
        vm.stopPrank();
    }

    /// getPrice() tests when adding or removing liquidity from metapool
    /// NOTE - for all liquidity changing tests, I'd like to talk with ppl on how the prices would be anticipated to be changed.

    /// @notice test getPrice() after genesis && liquidity increased at ratio of pool (33.33%PHO / 66.66% FRAXBP)
    function testGetPriceAddLiquidity() public {
        twapFixture();
        vm.startPrank(owner);
        uint256[2] memory metaLiquidity;
        metaLiquidity[0] = twoHundredFiftyThousand_d18;
        metaLiquidity[1] = twoHundredFiftyThousand_d18;
        fraxBPPhoMetapool.add_liquidity(metaLiquidity, 0);
        uint256 expectedNewUSDPHOPrice = _getNewUSDPHOPrice();
        uint256 oldUSDPHOPrice = phoTwapOracle.latestUSDPHOPrice();
        vm.expectEmit(true, true, false, true);
        emit PriceUpdated(expectedNewUSDPHOPrice, block.timestamp);
        phoTwapOracle.getPrice();
        uint256 newUSDPHOPrice = phoTwapOracle.latestUSDPHOPrice();
        assertEq(expectedNewUSDPHOPrice, newUSDPHOPrice);
        assertEq(oldUSDPHOPrice != newUSDPHOPrice, true);
        vm.stopPrank();
    }

    /// @notice test getPrice() after genesis && liquidity removed at pool ratio
    function testGetPriceRemoveLiquidity() public {
        twapFixture();
        vm.startPrank(owner);
        uint256[2] memory minAmounts = [uint256(0), uint256(0)];
        fraxBPPhoMetapool.remove_liquidity(
            fraxBPPhoMetapool.balanceOf(owner) / 2, minAmounts, owner
        );
        uint256 expectedNewUSDPHOPrice = _getNewUSDPHOPrice();
        uint256 oldUSDPHOPrice = phoTwapOracle.latestUSDPHOPrice();
        vm.expectEmit(true, true, false, true);
        emit PriceUpdated(expectedNewUSDPHOPrice, block.timestamp);
        phoTwapOracle.getPrice();
        uint256 newUSDPHOPrice = phoTwapOracle.latestUSDPHOPrice();
        assertEq(expectedNewUSDPHOPrice, newUSDPHOPrice);
        assertEq(oldUSDPHOPrice != newUSDPHOPrice, true);
        vm.stopPrank();
    }

    /// @notice test reversion in getPrice() when no liquidity in metapool
    function testCannotGetPrice() public {
        vm.startPrank(owner);
        uint256[2] memory min_amounts = [uint256(0), uint256(0)];
        fraxBPPhoMetapool.remove_liquidity(fraxBPPhoMetapool.balanceOf(owner), min_amounts, owner); // remove all liquidity
        vm.expectRevert("PHOTWAPOracle: metapool balance(s) cannot be 0");
        phoTwapOracle.getPrice();
        vm.stopPrank();
    }

    /// consult() tests

    /// @notice test revert on consult()
    function testCannotConsult() public {
        twapFixture();
        PHOTWAPOracle phoTwapOracle2 =
        new PHOTWAPOracle(address(pho), metaPoolFactoryAddress, fraxBPPool, fraxBPLPToken, fraxAddress, USDC_ADDRESS, address(priceFeed), period, fraxBPPhoMetapoolAddress, PRICE_THRESHOLD); // deploy PHOTWAPOracle

        vm.expectRevert("PHOTWAPOracle: PHOTWAPOracle not initialized");
        phoTwapOracle2.consult(address(fraxBPLP), oneHundred_d18);
    }

    /// @notice test consult() basic functionality querying for expected token[1] output
    function testConsultTokenOneOut() public {
        twapFixture();
        uint256 token1Out = phoTwapOracle.consult(address(pho), oneHundred_d18);
        uint256 expectedToken1Out = (phoTwapOracle.twap(0) * oneHundred_d18) / PHO_PRICE_PRECISION;
        assertEq(expectedToken1Out, token1Out);
    }

    /// @notice test consult() basic functionality querying for expected token[0] output
    function testConsultTokenZeroOut() public {
        twapFixture();
        uint256 token0Out = phoTwapOracle.consult(fraxBPLPToken, oneHundred_d18);
        uint256 expectedToken0Out = (phoTwapOracle.twap(1) * oneHundred_d18) / PHO_PRICE_PRECISION;
        assertEq(expectedToken0Out, token0Out);
    }

    /// @notice test revert on consult() for invalid tokens
    function testCannotConsultInvalidToken() public {
        twapFixture();
        vm.expectRevert("PHOTWAPOracle: invalid token");
        phoTwapOracle.consult(dummyAddress, oneHundred_d18);
    }

    /// setPriceSource() tests

    /// @notice tests revert for setting price source as zero address
    function testCannotSetPriceSourceAddressZero() public {
        twapFixture();
        vm.startPrank(owner);
        vm.expectRevert("PHOTWAPOracle: zero address detected");
        phoTwapOracle.setPriceSource(address(0));
    }

    /// @notice tests revert for setting price source as non-metapool
    function testCannotSetNonMetapoolPriceSource() public {
        twapFixture();
        vm.prank(owner);
        vm.expectRevert("PHOTWAPOracle: address does not point to a metapool");
        phoTwapOracle.setPriceSource(weth);
    }

    /// @notice tests revert for setting price source as metapool with no PHO as an underlying token
    function testCannotSetNonPhoPriceSource() public {
        twapFixture();
        vm.prank(owner);
        vm.expectRevert("PHOTWAPOracle: $PHO is not present in the metapool");
        phoTwapOracle.setPriceSource(fraxBPLUSD);
    }

    /// @notice tests basic setPriceSource() functionality
    function testSetPriceSource() public {
        twapFixture();
        assertEq(phoTwapOracle.initOracle(), true);
        address newSource = _deployFraxBPPHOPool();
        vm.expectEmit(true, false, false, true);
        emit PriceSourceUpdated(newSource);
        vm.prank(owner);
        phoTwapOracle.setPriceSource(newSource);
        assertEq(phoTwapOracle.initOracle(), false);
    }

    /// setPriceUpdateThreshold() tests

    /// @notice test setPriceUpdateThreshold() reverts when param is higher than allowed MAX_PRICE_THRESHOLD
    function testCannotSetPriceThreshold() public {
        vm.startPrank(owner);
        vm.expectRevert("PHOTWAPOracle: invalid priceUpdateThreshold value");
        phoTwapOracle.setPriceUpdateThreshold(1000001);
        vm.expectRevert("PHOTWAPOracle: invalid priceUpdateThreshold value");
        phoTwapOracle.setPriceUpdateThreshold(0);
        vm.stopPrank();
    }

    /// @notice tests basic setPriceUpdateThreshold() functionality
    function testSetPriceUpdateThreshold() public {
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit PriceUpdateThresholdChanged(999999);
        phoTwapOracle.setPriceUpdateThreshold(999999);
        assertEq(phoTwapOracle.priceUpdateThreshold(), 999999);
        vm.stopPrank();
    }

    /// helpers

    /// @notice carry out initial call for `getPrice()`, fast forward one period
    function twapFixture() public {
        _fundAndApproveFRAX(owner, fraxBPPhoMetapoolAddress, fiveHundredThousand_d18, 0);
        vm.startPrank(owner);
        phoTwapOracle.getPrice();
        vm.warp(phoTwapOracle.latestBlockTimestamp() + period + 1);
        vm.stopPrank();
    }

    /// @notice manual helper (similar to helper in PHOTWAPOracle.sol except with test vars)
    /// @return newest USD/FraxBP (scaled by d18) price answer derived from fraxBP balances and USD/Frax && USD/USDC priceFeeds
    function _getUSDPerFraxBP() internal returns (uint256) {
        uint256 fraxInFraxBP = fraxBP.balances(0); // FRAX - decimals: 18
        uint256 usdcInFraxBP = fraxBP.balances(1); // USDC - decimals: 6
        uint256 fraxPerFraxBP = fraxInFraxBP * PHO_PRICE_PRECISION / fraxBPLP.totalSupply(); // UNITS: (FRAX/FraxBP) - scaled by d18
        uint256 usdcPerFraxBP =
            usdcInFraxBP * PHO_PRICE_PRECISION * missing_decimals / fraxBPLP.totalSupply(); // UNITS: (USDC/FraxBP) - scaled by d18
        uint256 usdPerFraxBP = (
            ((fraxPerFraxBP * PHO_PRICE_PRECISION / priceFeed.getPrice(fraxAddress)))
                + (usdcPerFraxBP * PHO_PRICE_PRECISION / priceFeed.getPrice(USDC_ADDRESS))
        ); // UNITS: (USD/FraxBP) - scaled by d18
        return usdPerFraxBP;
    }

    /// @notice manual helper calc to compare against calcs within tested contract
    /// @return new expectedPHOUSDPrice
    /// NOTE - this is called after oracle is initialized with 1m PHO && 1m FraxBP genesis liquidity
    function _getNewUSDPHOPrice() internal returns (uint256) {
        uint256 token0balance = fraxBPPhoMetapool.balances(0);
        uint256 token1balance = fraxBPPhoMetapool.balances(1);
        uint256 token0Price = token1balance * PHO_PRICE_PRECISION / token0balance;
        uint256 token1Price = token0balance * PHO_PRICE_PRECISION / token1balance;

        uint256 expectedPeriodTimeElapsed = block.timestamp - phoTwapOracle.latestBlockTimestamp();
        uint256[2] memory expectedPriceCumulativeNew;
        expectedPriceCumulativeNew[0] = ((token0Price) * expectedPeriodTimeElapsed);

        expectedPriceCumulativeNew[1] = ((token1Price) * expectedPeriodTimeElapsed);
        uint256[2] memory expectedTwap;
        uint256[2] memory priceCumulativeLast =
            [phoTwapOracle.priceCumulativeLast(0), phoTwapOracle.priceCumulativeLast(1)];

        for (uint256 i = 0; i < 2; i++) {
            expectedTwap[i] =
                (expectedPriceCumulativeNew[i] - priceCumulativeLast[i]) / expectedPeriodTimeElapsed;
        } // want twap[0], the price FraxBP/PHO, we keep the other just in case

        uint256 expectedLatestUSDPHOPrice =
            (expectedTwap[0] * _getUSDPerFraxBP()) / PHO_PRICE_PRECISION; //  UNITS: (USD/PHO) = (FraxBP/PHO * USD/FraxBP) - decimals d18
        return expectedLatestUSDPHOPrice;
    }
}
