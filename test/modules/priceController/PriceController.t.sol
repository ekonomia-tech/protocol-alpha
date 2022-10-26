// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "../../BaseSetup.t.sol";
import "@external/curve/ICurvePool.sol";
import "@external/curve/ICurveFactory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@modules/priceController/PriceController.sol";

contract PriceControllerTest is BaseSetup {
    error ZeroAddress();
    error SameAddress();
    error ZeroValue();
    error SameValue();
    error CooldownPeriodAtLeastOneHour();
    error ValueNotInRange();
    error CooldownNotSatisfied();
    error NotEnoughBalanceInStabilizer();
    error TokenNotUnderlyingInMetapool();
    error AddressDoNotPointToMetapool();
    error PHONotPresentInMetapool();

    event OracleAddressSet(address indexed newOracleAddress);
    event CooldownPeriodUpdated(uint256 newCooldownPeriod);
    event PriceMitigationPercentageUpdated(uint256 newPriceMitigationPercentage);
    event TokensExchanged(
        address indexed dexPool,
        address indexed tokenSent,
        uint256 amountSent,
        address tokenReceived,
        uint256 amountReceived
    );
    event StabilizingTokenUpdated(address indexed newStabilizingToken);
    event MaxSlippageUpdated(uint256 newMaxSlippage);

    ICurvePool public curvePool;
    PriceController public priceController;

    /// Contract relevant test constants

    uint256 public constant OverPegOutBand = 103 * (10 ** 4);
    uint256 public constant OverPegInBand = 1005 * (10 ** 3);
    uint256 public constant UnderPegOutBand = 98 * (10 ** 4);
    uint256 public constant UnderPegInBand = 995 * (10 ** 3);
    uint256 public constant priceTarget = 10 ** 6;
    uint256 public constant fractionPrecision = 10 ** 5;

    function setUp() public {
        fraxBPLP = IERC20(FRAXBP_LP_TOKEN);
        fraxBP = ICurvePool(FRAXBP_ADDRESS);
        curveFactory = ICurveFactory(metaPoolFactoryAddress);

        _fundAndApproveUSDC(owner, address(fraxBP), TEN_THOUSAND_D6, TEN_THOUSAND_D6);

        fraxBPPhoMetapool = ICurvePool(_deployFraxBPPHOPool());

        console.log(address(fraxBPPhoMetapool));

        vm.prank(owner);
        priceController =
        new PriceController(address(pho), address(moduleManager), address(kernel), address(priceOracle), address(fraxBPPhoMetapool), 1 weeks, 10 ** 4, 50000,99000);

        vm.prank(PHOGovernance);
        moduleManager.addModule(address(priceController));

        vm.prank(TONGovernance);
        moduleManager.setPHOCeilingForModule(address(priceController), ONE_MILLION_D18 * 2);

        vm.prank(address(priceController));
        moduleManager.mintPHO(address(priceController), ONE_HUNDRED_THOUSAND_D18);

        _fundAndApproveUSDC(
            address(priceController),
            address(fraxBPPhoMetapool),
            ONE_HUNDRED_THOUSAND_D6,
            ONE_HUNDRED_THOUSAND_D6
        );
    }

    /// setOracleAddress

    function testSetOracleAddress() public {
        address newAddress = address(110);
        vm.expectEmit(true, false, false, true);
        emit OracleAddressSet(newAddress);
        vm.prank(owner);
        priceController.setOracleAddress(newAddress);
    }

    function testCannotSetOracleZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroAddress.selector));
        vm.prank(owner);
        priceController.setOracleAddress(address(0));
    }

    function testCannotSetOracleNotAllowed() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(user1);
        priceController.setOracleAddress(address(0));
    }

    function testCannotSetOracleSameAddress() public {
        vm.expectRevert(abi.encodeWithSelector(SameAddress.selector));
        vm.prank(owner);
        priceController.setOracleAddress(address(priceOracle));
    }

    /// setCooldownPeriod

    function testSetCooldownPeriod() public {
        uint256 newCooldownPeriod = 84600;
        vm.expectEmit(false, false, false, true);
        emit CooldownPeriodUpdated(newCooldownPeriod);
        vm.prank(owner);
        priceController.setCooldownPeriod(newCooldownPeriod);
    }

    function testCannotSetCooldownPeriodUnderHour() public {
        uint256 newCooldownPeriod = 100;
        vm.expectRevert(abi.encodeWithSelector(CooldownPeriodAtLeastOneHour.selector));
        vm.prank(owner);
        priceController.setCooldownPeriod(newCooldownPeriod);
    }

    function testCannotSetCooldownPeriodNotAllowed() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(user1);
        priceController.setCooldownPeriod(100);
    }

    function testCannotSetCooldownPeriodSameValue() public {
        uint256 currentCooldownPeriod = priceController.cooldownPeriod();
        vm.expectRevert(abi.encodeWithSelector(SameValue.selector));
        vm.prank(owner);
        priceController.setCooldownPeriod(currentCooldownPeriod);
    }

    /// setPriceMitigationPercentage

    function testSetPriceMitigationPercentage() public {
        uint256 newPriceMitigationPercentage = 20000;
        vm.expectEmit(true, true, false, false);
        emit PriceMitigationPercentageUpdated(newPriceMitigationPercentage);
        vm.prank(owner);
        priceController.setPriceMitigationPercentage(newPriceMitigationPercentage);
    }

    function testCannotSetPriceMitigationPercentageNotAllowed() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(user1);
        priceController.setPriceMitigationPercentage(0);
    }

    function testCannotSetPriceMitigationPercentageValueNotInRange() public {
        uint256 newPriceMitigationPercentageOver = 102000;
        uint256 newPriceMitigationPercentageUnder = 0;

        vm.expectRevert(abi.encodeWithSelector(ValueNotInRange.selector));
        vm.prank(owner);
        priceController.setPriceMitigationPercentage(newPriceMitigationPercentageOver);

        vm.expectRevert(abi.encodeWithSelector(ValueNotInRange.selector));
        vm.prank(owner);
        priceController.setPriceMitigationPercentage(newPriceMitigationPercentageUnder);
    }

    function testCannotSetPriceMitigationPercentageSameValue() public {
        uint256 currentPriceMitigationPercentage = priceController.priceMitigationPercentage();
        vm.expectRevert(abi.encodeWithSelector(SameValue.selector));
        vm.prank(owner);
        priceController.setPriceMitigationPercentage(currentPriceMitigationPercentage);
    }

    /// setMaxSlippage

    function testSetMaxSlippage() public {
        uint256 newMaxSlippage = 99500;
        vm.expectEmit(true, true, false, false);
        emit MaxSlippageUpdated(newMaxSlippage);
        vm.prank(owner);
        priceController.setMaxSlippage(newMaxSlippage);
    }

    function testCannotSetMaxSlippageNotAllowed() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(user1);
        priceController.setMaxSlippage(0);
    }

    function testCannotSetMaxSlippageValueNotInRange() public {
        uint256 newMaxSlippageOver = 102000;
        uint256 newMaxSlippageUnder = 0;

        vm.expectRevert(abi.encodeWithSelector(ValueNotInRange.selector));
        vm.prank(owner);
        priceController.setMaxSlippage(newMaxSlippageOver);

        vm.expectRevert(abi.encodeWithSelector(ValueNotInRange.selector));
        vm.prank(owner);
        priceController.setMaxSlippage(newMaxSlippageUnder);
    }

    function testCannotSetMaxSlippageSameValue() public {
        uint256 currentMaxSlippage = priceController.maxSlippage();
        vm.expectRevert(abi.encodeWithSelector(SameValue.selector));
        vm.prank(owner);
        priceController.setMaxSlippage(currentMaxSlippage);
    }

    /// checkPriceBand

    function testCheckPriceBand() public {
        uint256 diff;
        bool over;

        /// Over peg, out of band, 3 cents above
        priceOracle.setPHOUSDPrice(OverPegOutBand);
        (diff, over) = priceController.checkPriceBand(priceOracle.getPHOUSDPrice());

        assertEq(diff, OverPegOutBand - priceTarget);
        assertEq(over, true);

        /// Over peg, in band, 0.5 cents
        priceOracle.setPHOUSDPrice(OverPegInBand);
        (diff, over) = priceController.checkPriceBand(priceOracle.getPHOUSDPrice());

        assertEq(diff, OverPegInBand - priceTarget);
        assertEq(over, true);

        // Under peg, out of band, 2 cents
        priceOracle.setPHOUSDPrice(UnderPegOutBand);
        (diff, over) = priceController.checkPriceBand(priceOracle.getPHOUSDPrice());

        assertEq(diff, priceTarget - UnderPegOutBand);
        assertEq(over, false);

        // Under peg, in band, 0.5 cents
        priceOracle.setPHOUSDPrice(UnderPegInBand);
        (diff, over) = priceController.checkPriceBand(priceOracle.getPHOUSDPrice());

        assertEq(diff, priceTarget - UnderPegInBand);
        assertEq(over, false);
    }

    /// marketToTargetDiff

    /// Test terms:
    /// Total pho supply = 100,000
    /// pho price = 1.03
    /// over = 50%
    /// target price to reach = 1.015;
    /// change in percentage required to reach = 1.456%
    /// totalSupply * change = 1456$
    function testMarketToTargetDiffOverPeg() public {
        priceOracle.setPHOUSDPrice(OverPegOutBand);
        uint256 phoPrice = priceOracle.getPHOUSDPrice();
        uint256 phoTotalSupply = pho.totalSupply();
        (uint256 diff, bool over) = priceController.checkPriceBand(phoPrice);

        uint256 gapToMitigate =
            (diff * priceController.priceMitigationPercentage()) / fractionPrecision;
        /// Assuming over is 50%
        assertEq(gapToMitigate, diff / 2);

        uint256 diffs = priceController.marketToTargetDiff(phoPrice, diff);
        uint256 expectedGapInTokens =
            phoTotalSupply * (gapToMitigate * fractionPrecision / phoPrice) / fractionPrecision;

        assertEq(diffs, expectedGapInTokens);
    }

    /// Test terms:
    /// Total pho supply = 100,000
    /// pho price = 0.98
    /// over = 50%
    /// target price to reach = 0.99;
    /// change in percentage required to reach = 1.02%
    /// totalSupply * change = 1020$
    function testMarketToTargetDiffUnderPeg() public {
        priceOracle.setPHOUSDPrice(UnderPegOutBand);
        uint256 phoPrice = priceOracle.getPHOUSDPrice();
        uint256 phoTotalSupply = pho.totalSupply();
        (uint256 diff, bool over) = priceController.checkPriceBand(phoPrice);

        uint256 gapToMitigate =
            (diff * priceController.priceMitigationPercentage()) / fractionPrecision;
        /// Assuming over is 50%
        assertEq(gapToMitigate, diff / 2);

        uint256 diffs = priceController.marketToTargetDiff(phoPrice, diff);
        uint256 expectedGapInTokens =
            phoTotalSupply * (gapToMitigate * fractionPrecision / phoPrice) / fractionPrecision;

        assertEq(diffs, expectedGapInTokens);
    }

    /// _mintAndSellPHO()

    function testMintAndSellPHO() public {
        uint256 fraxBPPoolBalanceBefore = fraxBPPhoMetapool.balances(1);
        uint256 phoPoolBalanceBefore = fraxBPPhoMetapool.balances(0);
        uint256 fraxBPPriceControllerBalanceBefore = fraxBPLP.balanceOf(address(priceController));

        uint256 phoToExchange = ONE_THOUSAND_D18;
        uint256 minExpected = fraxBPPhoMetapool.get_dy(0, 1, phoToExchange);

        vm.expectEmit(true, true, false, true);
        emit TokensExchanged(
            address(fraxBPPhoMetapool), address(pho), phoToExchange, address(fraxBPLP), minExpected
            );
        vm.prank(owner);
        uint256 tokensReceived = priceController.mintAndSellPHO(phoToExchange);

        uint256 fraxBPPoolBalanceAfter = fraxBPPhoMetapool.balances(1);
        uint256 phoPoolBalanceAfter = fraxBPPhoMetapool.balances(0);
        uint256 fraxBPPriceControllerBalanceAfter = fraxBPLP.balanceOf(address(priceController));
        uint256 phoPriceControllerBalanceAfter = pho.balanceOf(address(priceController));

        /// taking into account fees and slippage
        assertApproxEqAbs(
            fraxBPPoolBalanceBefore, fraxBPPoolBalanceAfter + tokensReceived, 10 ** 18
        );
        assertEq(phoPoolBalanceBefore, phoPoolBalanceAfter - phoToExchange);
        assertEq(
            fraxBPPriceControllerBalanceBefore, fraxBPPriceControllerBalanceAfter - tokensReceived
        );
    }

    function testCannotMintAndSellPHOZeroAmount() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroValue.selector));
        vm.prank(owner);
        priceController.mintAndSellPHO(0);
    }

    function testCannotMintAndSellPHONotAllowed() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(user1);
        priceController.mintAndSellPHO(0);
    }

    /// buyAndBurnPHO()

    function testBuyAndBurnPHO() public {
        (int128 usdcIndex, int128 phoIndex,) =
            curveFactory.get_coin_indices(address(fraxBPPhoMetapool), address(usdc), address(pho));
        uint256[8] memory underlyingBalancesBefore =
            curveFactory.get_underlying_balances(address(fraxBPPhoMetapool));

        uint256 phoPoolBalanceBefore = underlyingBalancesBefore[uint128(phoIndex)];
        uint256 usdcPriceControllerBalanceBefore = usdc.balanceOf(address(priceController));

        /// d18 used to mimic the output of GapInToken function
        uint256 usdcToExchange = ONE_THOUSAND_D6;
        uint256 expectedPho =
            fraxBPPhoMetapool.get_dy_underlying(usdcIndex, phoIndex, usdcToExchange);

        vm.expectEmit(true, true, false, false);
        emit TokensExchanged(
            address(fraxBPPhoMetapool), address(usdc), usdcToExchange, address(pho), expectedPho
            );
        vm.prank(owner);
        uint256 tokensReceived = priceController.buyAndBurnPHO(usdcToExchange);

        uint256[8] memory underlyingBalancesAfter =
            curveFactory.get_underlying_balances(address(fraxBPPhoMetapool));

        uint256 phoPoolBalanceAfter = underlyingBalancesAfter[uint128(phoIndex)];
        uint256 usdcPriceControllerBalanceAfter = usdc.balanceOf(address(priceController));

        /// taking into account fees and slippage
        assertApproxEqAbs(phoPoolBalanceBefore, phoPoolBalanceAfter + expectedPho, 10 ** 18);
        assertEq(usdcPriceControllerBalanceBefore, usdcPriceControllerBalanceAfter + usdcToExchange);
    }

    function testCannotBuyAndBurnPHOZeroAmount() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroValue.selector));
        vm.prank(owner);
        priceController.buyAndBurnPHO(0);
    }

    function testCannotBuyAndBurnPHONotAllowed() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(user1);
        priceController.buyAndBurnPHO(0);
    }

    function testCannotBuyAndBurnPHONotEnoughBalance() public {
        uint256 priceControllerUSDCBalance = usdc.balanceOf(address(priceController));

        vm.prank(address(priceController));
        usdc.transfer(owner, priceControllerUSDCBalance);

        assertEq(usdc.balanceOf(address(priceController)), 0);

        vm.expectRevert(abi.encodeWithSelector(NotEnoughBalanceInStabilizer.selector));
        vm.prank(owner);
        priceController.buyAndBurnPHO(TEN_THOUSAND_D18);
    }

    /// stabilize

    function testStabilizeOverPegOutBand() public {
        (int128 phoIndex, int128 fraxBPLPIndex,) = curveFactory.get_coin_indices(
            address(fraxBPPhoMetapool), address(pho), address(fraxBPLP)
        );

        uint256 phoTotalSupplyBefore = pho.totalSupply();
        uint256 fraxBPPriceControllerBalanceBefore = fraxBPLP.balanceOf(address(priceController));

        priceOracle.setPHOUSDPrice(OverPegOutBand);
        uint256 phoPrice = priceOracle.getPHOUSDPrice();
        (uint256 diff, bool over) = priceController.checkPriceBand(phoPrice);
        uint256 priceMitigationPart = priceController.marketToTargetDiff(phoPrice, diff);
        uint256 expectedFraxBP =
            fraxBPPhoMetapool.get_dy(phoIndex, fraxBPLPIndex, priceMitigationPart);

        vm.prank(owner);
        bool stabilized = priceController.stabilize();

        uint256 phoTotalSupplyAfter = pho.totalSupply();
        uint256 fraxBPPriceControllerBalanceAfter = fraxBPLP.balanceOf(address(priceController));

        assertEq(phoTotalSupplyAfter, phoTotalSupplyBefore + priceMitigationPart);
        assertEq(
            fraxBPPriceControllerBalanceBefore, fraxBPPriceControllerBalanceAfter - expectedFraxBP
        );
        assertTrue(stabilized);
    }

    function testStabilizeUnderPegOutBand() public {
        (int128 usdcIndex, int128 phoIndex,) =
            curveFactory.get_coin_indices(address(fraxBPPhoMetapool), address(usdc), address(pho));

        uint256 phoTotalSupplyBefore = pho.totalSupply();
        uint256 usdcPriceControllerBalanceBefore = usdc.balanceOf(address(priceController));

        priceOracle.setPHOUSDPrice(UnderPegOutBand);
        uint256 phoPrice = priceOracle.getPHOUSDPrice();
        (uint256 diff, bool over) = priceController.checkPriceBand(phoPrice);
        uint256 priceMitigationPart = priceController.marketToTargetDiff(phoPrice, diff);
        uint256 expectedPho =
            fraxBPPhoMetapool.get_dy_underlying(usdcIndex, phoIndex, priceMitigationPart / 10 ** 12);

        vm.prank(owner);
        bool stabilized = priceController.stabilize();

        uint256 phoTotalSupplyAfter = pho.totalSupply();
        uint256 usdcPriceControllerBalanceAfter = usdc.balanceOf(address(priceController));

        assertApproxEqAbs(phoTotalSupplyAfter, phoTotalSupplyBefore - expectedPho, 10 ** 18);
        assertEq(
            usdcPriceControllerBalanceBefore,
            usdcPriceControllerBalanceAfter + (priceMitigationPart / 10 ** 12)
        );
        assertTrue(priceController.lastCooldownReset() - block.timestamp < 3600);
        assertTrue(stabilized);
    }

    function testStabilizePricePegged() public {
        vm.prank(owner);
        bool stabilized = priceController.stabilize();
        assertTrue(priceController.lastCooldownReset() - block.timestamp < 3600);
        assertFalse(stabilized);
    }

    function testStabilizePriceInBandOverPeg() public {
        priceOracle.setPHOUSDPrice(OverPegInBand);
        vm.prank(owner);
        bool stabilized = priceController.stabilize();

        assertFalse(stabilized);
        assertTrue(priceController.lastCooldownReset() - block.timestamp < 3600);
    }

    function testStabilizePriceInBandUnderPeg() public {
        priceOracle.setPHOUSDPrice(UnderPegInBand);
        vm.prank(owner);
        bool stabilized = priceController.stabilize();

        assertFalse(stabilized);
        assertTrue(priceController.lastCooldownReset() - block.timestamp < 3600);
    }

    function testCannotStabilizeInCooldown() public {
        vm.prank(owner);
        bool stabilized = priceController.stabilize();
        assertTrue(priceController.lastCooldownReset() - block.timestamp < 3600);
        assertFalse(stabilized);

        vm.warp(block.timestamp + 100);

        priceOracle.setPHOUSDPrice(OverPegOutBand);
        vm.expectRevert(abi.encodeWithSelector(CooldownNotSatisfied.selector));
        vm.prank(owner);
        stabilized = priceController.stabilize();
        assertFalse(stabilized);
    }
}
