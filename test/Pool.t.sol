// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/contracts/TON.sol";
import "src/contracts/Pool.sol";
import "src/contracts/PHO.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "src/oracle/DummyOracle.sol";
import "src/contracts/PIDController.sol";
import "./BaseSetup.t.sol";
import {PoolLibrary} from "src/libraries/PoolLibrary.sol";

contract PoolTest is BaseSetup {
    function setUp() public {
        _fundAndApproveUSDC(user1, address(pool_usdc), tenThousand_d6, tenThousand_d6);
    }

    /// mint1t1PHO

    function testMint1t1PHO() public {
        uint256 collateralAmount = oneHundred_d6;
        uint256 minOut = oneHundred_d18 - ten_d18;
        uint256 expectedOut = collateralAmount * (missing_decimals);

        Balance memory balanceBeforeMint = _getAccountBalance(user1);
        vm.prank(user1);
        pool_usdc.mint1t1PHO(collateralAmount, minOut);

        Balance memory balanceAfterMint = _getAccountBalance(user1);

        assertEq(balanceAfterMint.pho, balanceBeforeMint.pho + expectedOut);
        assertEq(balanceAfterMint.usdc, balanceBeforeMint.usdc - collateralAmount);
    }

    function testCannotMintIfFractional() public {
        uint256 collateralAmount = oneHundred_d6;
        uint256 minOut = oneHundred_d18 - ten_d18;

        // Decrease collateral ratio
        priceOracle.setPHOUSDPrice(1020000);
        pid.refreshCollateralRatio();

        vm.prank(user1);
        vm.expectRevert("Collateral ratio must be >= 1");
        pool_usdc.mint1t1PHO(collateralAmount, minOut);
    }

    function testCannotMintIfCeilingReached() public {
        uint256 collateralAmount = oneHundred_d6;
        uint256 minOut = oneHundred_d18 - ten_d18;

        // Lower the ceiling
        vm.startPrank(owner);
        pool_usdc.setPoolParameters(
            10e6,
            pool_usdc.bonus_rate(),
            pool_usdc.redemption_delay(),
            pool_usdc.minting_fee(),
            pool_usdc.redemption_fee(),
            pool_usdc.buyback_fee(),
            pool_usdc.recollat_fee()
        );
        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert("[Pool's Closed]: Ceiling reached");
        pool_usdc.mint1t1PHO(collateralAmount, minOut);
    }

    function testCannotMintSlippageLimitReached() public {
        uint256 collateralAmount = oneHundred_d6;
        uint256 minOut = 99 * (one_d18);

        // Attempt to mint 100pho when pool ceiling is 10

        priceOracle.setUSDCUSDPrice(980000);
        vm.prank(user1);
        vm.expectRevert("Slippage limit reached");
        pool_usdc.mint1t1PHO(collateralAmount, minOut);
    }

    // mintFractionalPHO

    // To mint fractional, we have to set the CR to lower than 1. The way to do that is increasing the market price of PHO
    // which will result in reduction of the CR.
    function testMintFractionalPHO() public {
        uint256 collateralAmount = oneHundred_d6;
        uint256 tonAmount = oneHundred_d18;
        uint256 totalToMint = oneHundred_d18;
        uint256 minOut = oneHundred_d18 - ten_d18;

        priceOracle.setPHOUSDPrice((1020000));
        pid.refreshCollateralRatio();

        _fundAndApproveTON(user1, address(pool_usdc), tonAmount, tonAmount);

        (uint256 collRequired, uint256 tonRequired) = _calcFractionalParts(totalToMint);

        Balance memory balanceBeforeMint = _getAccountBalance(user1);

        vm.prank(user1);
        pool_usdc.mintFractionalPHO(collRequired, tonRequired, minOut);

        Balance memory balanceAfterMint = _getAccountBalance(user1);

        assertEq(balanceAfterMint.pho, balanceBeforeMint.pho + totalToMint);
        assertEq(balanceAfterMint.usdc, balanceBeforeMint.usdc - collRequired);
        assertEq(balanceAfterMint.ton, balanceBeforeMint.ton - tonRequired);
    }

    function testCannotMintFractionalWhenPaused() public {
        vm.prank(owner);
        pool_usdc.toggleMinting();
        vm.prank(user1);
        vm.expectRevert("Minting is paused");
        pool_usdc.mintFractionalPHO(PRICE_PRECISION, one_d18, oneHundred_d18 - ten_d18);
    }

    // attempt to mint fractional with CR 100%
    function testCannotMintFractionalWrongCollatRatio() public {
        uint256 usdcAmount = 120 * (one_d6);
        uint256 tonAmount = oneHundred_d18;
        uint256 totalToMint = oneHundred_d18;
        uint256 minOut = oneHundred_d18 - ten_d18;

        _fundAndApproveTON(user1, address(pool_usdc), tonAmount, tonAmount);

        (uint256 collRequired, uint256 tonRequired) = _calcFractionalParts(totalToMint);

        vm.prank(user1);
        vm.expectRevert("Collateral ratio needs to be between .000001 and .999999");
        pool_usdc.mintFractionalPHO(collRequired, tonRequired, minOut);
    }

    function testCannotMintFractionalWhenPoolCeiling() public {
        uint256 usdcAmount = 120 * (one_d6);
        uint256 tonAmount = oneHundred_d18;
        uint256 totalToMint = oneHundred_d18;
        uint256 minOut = oneHundred_d18 - ten_d18;

        priceOracle.setPHOUSDPrice((1020000));
        pid.refreshCollateralRatio();

        // Lower the ceiling
        vm.startPrank(owner);
        pool_usdc.setPoolParameters(
            10e6,
            pool_usdc.bonus_rate(),
            pool_usdc.redemption_delay(),
            pool_usdc.minting_fee(),
            pool_usdc.redemption_fee(),
            pool_usdc.buyback_fee(),
            pool_usdc.recollat_fee()
        );
        vm.stopPrank();

        _fundAndApproveTON(user1, address(pool_usdc), tonAmount, tonAmount);

        (uint256 collRequired, uint256 tonRequired) = _calcFractionalParts(totalToMint);

        vm.prank(user1);
        vm.expectRevert("Pool ceiling reached, no more pho can be minted with this collateral");
        pool_usdc.mintFractionalPHO(collRequired, tonRequired, minOut);
    }

    function testCannotMintFractionalSlippage() public {
        uint256 collateralAmount = oneHundred_d6;
        uint256 tonAmount = oneHundred_d18;
        uint256 totalToMint = oneHundred_d18;
        uint256 minOut = 100 * (one_d18);

        priceOracle.setPHOUSDPrice((1020000));
        pid.refreshCollateralRatio();

        _fundAndApproveTON(user1, address(pool_usdc), tonAmount, tonAmount);

        priceOracle.setUSDCUSDPrice(980000);
        priceOracle.setTONUSDPrice(priceOracle.getTONUSDPrice() * 98 / 100);

        (uint256 collRequired, uint256 tonRequired) = _calcFractionalParts(totalToMint);

        vm.prank(user1);
        vm.expectRevert("Slippage limit reached");
        pool_usdc.mintFractionalPHO(collRequired, tonRequired, minOut);
    }

    function testCannotMintFractionalNotEnoughTON() public {
        uint256 usdcAmount = oneHundred_d6 + fifty_d6;
        uint256 tonAmount = oneHundred_d18;
        uint256 totalToMint = oneHundred_d18;
        uint256 minOut = oneHundred_d18 - ten_d18;

        priceOracle.setPHOUSDPrice((1020000));
        pid.refreshCollateralRatio();

        _fundAndApproveTON(user1, address(pool_usdc), tonAmount, tonAmount);

        (uint256 collRequired, uint256 tonRequired) = _calcFractionalParts(totalToMint);

        vm.prank(user1);
        vm.expectRevert("Not enough TON inputted");
        pool_usdc.mintFractionalPHO(collRequired, 0, minOut);
    }

    // redeem1t1PHO

    function testRedeem1t1PHO() public {
        Balance memory balanceBeforeRedeem = _mintPHO(user1, oneHundred_d6);
        uint256 redeemAmount = fifty_d18;
        uint256 unclaimedPoolCollateralBefore = pool_usdc.unclaimedPoolCollateral();

        vm.startPrank(user1);
        pho.approve(address(pool_usdc), redeemAmount);
        pool_usdc.redeem1t1PHO(redeemAmount, ten_d6);
        Balance memory balanceAfterRedeem = _getAccountBalance(user1);

        vm.stopPrank();
        assertEq(balanceAfterRedeem.pho, balanceBeforeRedeem.pho - redeemAmount);
        assertEq(pool_usdc.redeemCollateralBalances(user1), fifty_d6);
        assertEq(pool_usdc.unclaimedPoolCollateral(), unclaimedPoolCollateralBefore + fifty_d6);
        assertEq(pool_usdc.lastRedeemed(user1), block.number);
    }

    function testCannotRedeem1t1Paused() public {
        vm.prank(owner);
        pool_usdc.toggleRedeeming();

        vm.expectRevert("Redeeming is paused");
        pool_usdc.redeem1t1PHO(fifty_d18, ten_d6);
    }

    function testCannotRedeem1t1RatioUnder1() public {
        priceOracle.setPHOUSDPrice(1020000);
        pid.refreshCollateralRatio();

        vm.expectRevert("Collateral ratio must be == 1");
        pool_usdc.redeem1t1PHO(fifty_d18, ten_d6);
    }

    function testCannotRedeem1t1NotEnoughColatInPool() public {
        uint256 usdcPoolBalance = usdc.balanceOf(address(pool_usdc));
        vm.prank(address(pool_usdc));
        usdc.transfer(user1, usdcPoolBalance);

        vm.expectRevert("Not enough collateral in pool");
        pool_usdc.redeem1t1PHO(fifty_d18, ten_d6);
    }

    function testCannotRedeem1t1Slippage() public {
        _mintPHO(user1, oneHundred_d6);

        priceOracle.setUSDCUSDPrice(1020000);

        vm.expectRevert("Slippage limit reached");
        pool_usdc.redeem1t1PHO(fifty_d18, 495 * (10 ** 5));
    }

    /// redeemFractionalPHO

    function testRedeemFractionalPHO() public {
        // The fractional minting process reduces the global collateral ratio
        Balance memory balanceBeforeRedeem = _mintFractionalPHO(user1, oneHundred_d18, 1020000);

        uint256 amountToRedeem = balanceBeforeRedeem.pho / 2;
        (uint256 collPart, uint256 tonPart) = _calculateRedeemingParts(amountToRedeem);

        vm.startPrank(user1);
        pho.approve(address(pool_usdc), amountToRedeem);
        pool_usdc.redeemFractionalPHO(amountToRedeem, 0, 0);
        Balance memory balanceAfterRedeem = _getAccountBalance(user1);
        vm.stopPrank();

        assertEq(balanceAfterRedeem.pho, balanceBeforeRedeem.pho - amountToRedeem);
        assertEq(pool_usdc.redeemTONBalances(user1), tonPart);
        assertEq(pool_usdc.redeemCollateralBalances(user1), collPart);
    }

    function testCannotRedeemFractionalPaused() public {
        vm.prank(owner);
        pool_usdc.toggleRedeeming();

        vm.expectRevert("Redeeming is paused");
        pool_usdc.redeemFractionalPHO(oneHundred_d18, 0, 0);
    }

    function testCannotRedeemFractionalWhenCollIs1() public {
        vm.expectRevert("Collateral ratio needs to be between .000001 and .999999");
        pool_usdc.redeemFractionalPHO(oneHundred_d18, 0, 0);
    }

    function testCannotRedeemFractionalNotEnoughCollat() public {
        priceOracle.setPHOUSDPrice(1020000);
        pid.refreshCollateralRatio();
        uint256 usdcPoolBalance = usdc.balanceOf(address(pool_usdc));
        vm.prank(address(pool_usdc));
        usdc.transfer(user1, usdcPoolBalance);

        vm.expectRevert("Not enough collateral in pool");
        pool_usdc.redeemFractionalPHO(oneHundred_d18, 0, 0);
    }

    function testCannotRedeemFractionalSlippage() public {
        _mintFractionalPHO(user1, oneHundred_d18, 1020000);

        priceOracle.setTONUSDPrice(priceOracle.getTONUSDPrice() * 102 / 100);

        // the minting function is putting the collateral ratio on 99.75%, so expected ton is pretty low as it is.
        vm.expectRevert("Slippage limit reached [TON]");
        pool_usdc.redeemFractionalPHO(oneHundred_d18, one_d18, 0);

        priceOracle.setUSDCUSDPrice(1020000);

        vm.expectRevert("Slippage limit reached [collateral]");
        pool_usdc.redeemFractionalPHO(oneHundred_d18, 0, 99 * (10 ** 6));
    }

    /// collectRedemption

    function testCollectRedemption() public {
        uint256 originalBlock = block.number;
        testRedeemFractionalPHO();
        Balance memory userBalanceBeforeCollection = _getAccountBalance(user1);
        uint256 collateralInPool = pool_usdc.redeemCollateralBalances(user1);
        uint256 tonInPool = pool_usdc.redeemTONBalances(user1);

        vm.roll(originalBlock + 5);
        vm.prank(user1);
        pool_usdc.collectRedemption();

        Balance memory userBalanceAfterCollection = _getAccountBalance(user1);

        assertEq(pool_usdc.redeemCollateralBalances(user1), 0);
        assertEq(userBalanceAfterCollection.ton, userBalanceBeforeCollection.ton + tonInPool);
        assertEq(
            userBalanceAfterCollection.usdc, userBalanceBeforeCollection.usdc + collateralInPool
        );
    }

    function testCannotCollectRedemptionBadDelay() public {
        testRedeemFractionalPHO();
        vm.prank(user1);
        vm.expectRevert("Must wait for redemption_delay blocks before collecting redemption");
        pool_usdc.collectRedemption();
    }

    /// toggleMinting

    function testToggleMinting() public {
        vm.expectEmit(true, false, false, false);
        emit MintingToggled(true);
        vm.prank(owner);
        pool_usdc.toggleMinting();
    }

    function testFailToggleMintingUnauthorized() public {
        vm.prank(user1);
        pool_usdc.toggleMinting();
    }

    /// toggleRedeeming

    function testToggleRedeeming() public {
        vm.expectEmit(true, false, false, false);
        emit RedeemingToggled(true);
        vm.prank(owner);
        pool_usdc.toggleRedeeming();
    }

    function testFailToggleRedeemingUnauthorized() public {
        vm.prank(user1);
        pool_usdc.toggleRedeeming();
    }

    /// toggleCollateralPrice

    function testToggleCollateralPrice() public {
        uint256 newPausedPrice = 1020000;
        vm.expectEmit(true, false, false, false);
        emit CollateralPriceToggled(true);

        vm.startPrank(owner);

        pool_usdc.toggleCollateralPrice(newPausedPrice);
        assertEq(pool_usdc.pausedPrice(), newPausedPrice);

        vm.expectEmit(true, false, false, false);
        emit CollateralPriceToggled(false);

        pool_usdc.toggleCollateralPrice(0);
        assertEq(pool_usdc.pausedPrice(), 0);

        vm.stopPrank();
    }

    function testFailToggleCollateralPriceUnauthorized() public {
        vm.prank(user1);
        pool_usdc.toggleCollateralPrice(0);
    }

    /// RecollateralizePHO
    /// testing recollateralization requires putting the system in a state that will allow it.
    /// The process is straight forward considering the PHO-USD is 1 USDC-USD is 1
    /// Actual recollat process checks how much collateral is needed to increase the protocol back to the desired CR
    /// and allowed only that amount to be deposited. The depositor receives extra ton based on bonus rate.
    function testRecollateralizePHO() public {
        _mintPHO(user1, oneHundred_d6);
        _fundAndApproveUSDC(user1, address(pool_usdc), 1000 * (10 ** 6), 1000 * (10 ** 6));

        /// remove physical collateral instead of changing the USDC price.
        /// It works the same way since the goal is to have the collateral dollar value lower then what's needed.
        vm.prank(address(pool_usdc));
        usdc.transfer(user1, fifty_d6);

        uint256 poolCollateralBefore = usdc.balanceOf(address(pool_usdc));
        uint256 collateral_amount = fifty_d6;
        uint256 collateral_amount_d18 = collateral_amount * (missing_decimals);
        // calculate the expected ton in account to the bonus rate and recollat fee
        uint256 expectedTON = collateral_amount_d18
            * (10 ** 6 + pool_usdc.bonus_rate() - pool_usdc.recollat_fee())
            / priceOracle.getTONUSDPrice();
        Balance memory balanceBeforeRecollat = _getAccountBalance(user1);

        vm.prank(user1);
        pool_usdc.recollateralizePHO(collateral_amount, 0);

        Balance memory balanceAfterRecollat = _getAccountBalance(user1);
        assertEq(balanceAfterRecollat.ton, expectedTON);
        assertEq(balanceAfterRecollat.usdc, balanceBeforeRecollat.usdc - collateral_amount);
        assertEq(usdc.balanceOf(address(pool_usdc)), poolCollateralBefore + collateral_amount);
    }

    function testCannotRecollateralizePaused() public {
        vm.prank(owner);
        pool_usdc.toggleRecollateralize();

        vm.expectRevert("Recollateralize is paused");
        vm.prank(user1);
        pool_usdc.recollateralizePHO(oneHundred_d6, 0);
    }

    function testCannotRecollateralizeSlippage() public {
        uint256 collateral_amount = fifty_d6;
        uint256 collateral_amount_d18 = collateral_amount * (missing_decimals);
        uint256 expectedTON = collateral_amount_d18
            * (10 ** 6 + pool_usdc.bonus_rate() - pool_usdc.recollat_fee())
            / priceOracle.getTONUSDPrice();
        uint256 minTONOut = expectedTON * 99 / 100;

        _mintPHO(user1, oneHundred_d6);
        _fundAndApproveUSDC(user1, address(pool_usdc), 1000 * (10 ** 6), 1000 * (10 ** 6));

        priceOracle.setTONUSDPrice(priceOracle.getTONUSDPrice() * 102 / 100);
        vm.expectRevert("Slippage limit reached");
        vm.prank(user1);
        pool_usdc.recollateralizePHO(collateral_amount, minTONOut);
    }

    function testToggleRecollateralize() public {
        vm.expectEmit(true, false, false, false);
        emit RecollateralizeToggled(true);
        vm.prank(owner);
        pool_usdc.toggleRecollateralize();
    }

    function testFailToggleRecollateralizeUnauthorized() public {
        vm.prank(user1);
        pool_usdc.toggleRecollateralize();
    }

    /// buyBackTONs

    /// when the system has more collateral value in it than the needed to achieve the exact CR, the protocol will buy ton back
    /// and will pay collateral.
    /// The library function checks if there is any excess collateral in the system. if there is, the system allowes buying back
    /// ton and give away collateral to reduce the CR back to the desired CR.
    function testBuyBackTONs() public {
        uint256 tonAmount = ten_d18;
        uint256 tonPrice = priceOracle.getTONUSDPrice();
        uint256 collPrice = priceOracle.getPHOUSDPrice();
        // Fill the pool with collateral (must be a large amount that will correspond to a single step under %100 collateralization)
        // The lower the CR, the higher the excess amount will be with the same amounts.

        // set buyback fee to 0.25%
        vm.startPrank(owner);
        pool_usdc.setPoolParameters(
            pool_usdc.pool_ceiling(),
            pool_usdc.bonus_rate(),
            pool_usdc.redemption_delay(),
            pool_usdc.minting_fee(),
            pool_usdc.redemption_fee(),
            250,
            pool_usdc.recollat_fee()
        );
        vm.stopPrank();

        _fundAndApproveTON(user1, address(pool_usdc), oneHundred_d18, oneHundred_d18);
        priceOracle.setPHOUSDPrice(1040000);
        pid.refreshCollateralRatio();

        // calculated as the dollar amount expected to receive for a deposited ton to the protocol
        uint256 expectedCollateral =
            tonAmount * tonPrice / one_d18 * (10 ** 6 - pool_usdc.buyback_fee()) / 10 ** 6;

        Balance memory balanceBeforeBuyBack = _getAccountBalance(user1);
        vm.prank(user1);

        // depositing 10 tons (100$ worth buy ton_price = 10e6 althought the actual excess is 250$)
        pool_usdc.buyBackTON(ten_d18, 0);
        Balance memory balanceAfterBuyBack = _getAccountBalance(user1);

        assertEq(balanceAfterBuyBack.usdc, balanceBeforeBuyBack.usdc + expectedCollateral);
        assertEq(balanceAfterBuyBack.ton, balanceBeforeBuyBack.ton - tonAmount);
    }

    function testCannotBuyBackTONPaused() public {
        vm.prank(owner);
        pool_usdc.toggleBuyBack();

        vm.expectRevert("Buyback is paused");
        vm.prank(user1);
        pool_usdc.buyBackTON(ten_d18, 0);
    }

    // buy back will not pass because the amount of collateral is enough. will revert in library function
    function testCannotBuyBackTONNoExcess() public {
        vm.prank(user1);
        vm.expectRevert("No excess collateral to buy back!");
        pool_usdc.buyBackTON(ten_d18, 0);
    }

    // define a low excess
    // mint 100 means the excess is lower than 1 dollar. therefore anything above the excess will revert in library function
    function testCannotBuyBackTONMoreThanExcess() public {
        uint256 tonAmount = fiveHundred_d18;
        uint256 tonPrice = priceOracle.getTONUSDPrice();
        uint256 collPrice = priceOracle.getPHOUSDPrice();

        // set buyback fee to 0.25%
        vm.startPrank(owner);
        pool_usdc.setPoolParameters(
            pool_usdc.pool_ceiling(),
            pool_usdc.bonus_rate(),
            pool_usdc.redemption_delay(),
            pool_usdc.minting_fee(),
            pool_usdc.redemption_fee(),
            250,
            pool_usdc.recollat_fee()
        );

        priceOracle.setPHOUSDPrice(1060000);
        pid.refreshCollateralRatio();

        vm.stopPrank();
        vm.expectRevert("You are trying to buy back more than the excess!");
        pool_usdc.buyBackTON(tonAmount, 0);
    }

    // function acts same as main test but requires ton_min higher than possible in respect to the amounts entered
    function testCannotBuyBackTONSlippage() public {
        uint256 tonAmount = ten_d18;
        uint256 tonPrice = priceOracle.getTONUSDPrice();
        uint256 collPrice = priceOracle.getUSDCUSDPrice();
        uint256 minOut = tonAmount * tonPrice / (10 ** 6) * 99 / 100 / (missing_decimals);
        // _mintPHO(user1, oneHundred_d6 * 1000);

        // set buyback fee to 0.25%
        vm.startPrank(owner);
        pool_usdc.setPoolParameters(
            pool_usdc.pool_ceiling(),
            pool_usdc.bonus_rate(),
            pool_usdc.redemption_delay(),
            pool_usdc.minting_fee(),
            pool_usdc.redemption_fee(),
            250,
            pool_usdc.recollat_fee()
        );
        vm.stopPrank();

        priceOracle.setPHOUSDPrice(1040000);
        pid.refreshCollateralRatio();

        priceOracle.setUSDCUSDPrice(1020000);

        vm.prank(user1);
        vm.expectRevert("Slippage limit reached");
        pool_usdc.buyBackTON(ten_d18, minOut);
    }

    function testToggleBuyBack() public {
        vm.expectEmit(true, false, false, false);
        emit BuybackToggled(true);
        vm.prank(owner);
        pool_usdc.toggleBuyBack();
    }

    function testFailToggleBuybackUnauthorized() public {
        vm.prank(user1);
        pool_usdc.toggleBuyBack();
    }

    /// Helpers

    function _calcFractionalParts(uint256 _totalPHOOut)
        public
        returns (uint256 collRequired, uint256 tonRequired)
    {
        uint256 gcr = pid.global_collateral_ratio();
        uint256 tonPrice = priceOracle.getTONUSDPrice();
        uint256 usdcPrice = priceOracle.getUSDCUSDPrice();

        uint256 totalDollarValue = _totalPHOOut;

        uint256 collDollarPortion = (totalDollarValue * gcr) / (missing_decimals);
        uint256 tonDollarPortion = (totalDollarValue * (PRICE_PRECISION - gcr)) / PRICE_PRECISION;

        collRequired = collDollarPortion / usdcPrice;
        tonRequired = (tonDollarPortion * PRICE_PRECISION) / tonPrice;
    }

    function _calculateRedeemingParts(uint256 _redeemAmount)
        private
        returns (uint256 collateralAmount, uint256 tonAmount)
    {
        uint256 gcr = pid.global_collateral_ratio();
        uint256 tonPrice = priceOracle.getTONUSDPrice();
        uint256 usdcPrice = priceOracle.getUSDCUSDPrice();
        uint256 redemptionFee = pool_usdc.redemption_fee();

        uint256 redeemAmountPostFee =
            _redeemAmount * (PRICE_PRECISION - redemptionFee) / PRICE_PRECISION;
        uint256 tonDollarValue = redeemAmountPostFee - (redeemAmountPostFee * gcr / PRICE_PRECISION);
        tonAmount = tonDollarValue * PRICE_PRECISION / tonPrice;

        uint256 redeemAmountPrecision = redeemAmountPostFee / (missing_decimals);
        uint256 collDollarValue = redeemAmountPrecision * gcr / PRICE_PRECISION;
        collateralAmount = collDollarValue * PRICE_PRECISION / usdcPrice;
    }

    function _mintPHO(address _to, uint256 _amountToMint) private returns (Balance memory) {
        _fundAndApproveUSDC(_to, address(pool_usdc), _amountToMint * 2, _amountToMint * 2);

        vm.prank(_to);
        pool_usdc.mint1t1PHO(_amountToMint, _amountToMint * (missing_decimals));

        return _getAccountBalance(_to);
    }

    function _mintFractionalPHO(address _to, uint256 _amountToMint, uint256 _phoPrice)
        private
        returns (Balance memory)
    {
        uint256 tonAmount = _amountToMint * 10;
        uint256 usdcAmount = _amountToMint / (missing_decimals) * 10;

        priceOracle.setPHOUSDPrice(_phoPrice);
        pid.refreshCollateralRatio();

        _fundAndApproveTON(user1, address(pool_usdc), tonAmount, tonAmount);

        (uint256 collRequired, uint256 tonRequired) = _calcFractionalParts(_amountToMint);

        vm.prank(user1);
        pool_usdc.mintFractionalPHO(collRequired, tonRequired, 0);

        return _getAccountBalance(_to);
    }

    // events

    event PoolParametersSet(
        uint256 new_ceiling,
        uint256 new_bonus_rate,
        uint256 new_redemption_delay,
        uint256 new_mint_fee,
        uint256 new_redeem_fee,
        uint256 new_buyback_fee,
        uint256 new_recollat_fee
    );
    event TimelockSet(address new_timelock);
    event MintingToggled(bool toggled);
    event RedeemingToggled(bool toggled);
    event RecollateralizeToggled(bool toggled);
    event BuybackToggled(bool toggled);
    event CollateralPriceToggled(bool toggled);
}
