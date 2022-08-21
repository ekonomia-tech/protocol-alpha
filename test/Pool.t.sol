// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/contracts/Share.sol";
import "src/contracts/Pool.sol";
import "src/contracts/EUSD.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "src/oracle/DummyOracle.sol";
import "src/contracts/PIDController.sol";
import "./BaseSetup.t.sol";
import {PoolLibrary} from "src/libraries/PoolLibrary.sol";

contract PoolTest is BaseSetup {

    function setUp() public {
        _fundAndApproveUSDC(user1, address(pool_usdc), tenThousand_d6, tenThousand_d6);
    }

    /// mint1t1EUSD

    function testMint1t1EUSD() public {
        uint256 collateralAmount = oneHundred_d6;
        uint256 minOut = oneHundred_d18 - ten_d18;
        uint256 expectedOut = collateralAmount * (missing_decimals);
        
        Balance memory balanceBeforeMint = _getAccountBalance(user1);
        vm.prank(user1);
        pool_usdc.mint1t1EUSD(collateralAmount, minOut);
        
        Balance memory balanceAfterMint = _getAccountBalance(user1);

        assertEq(balanceAfterMint.eusd, balanceBeforeMint.eusd + expectedOut);
        assertEq(balanceAfterMint.usdc, balanceBeforeMint.usdc - collateralAmount);
    }

    function testCannotMintIfFractional() public {
        uint256 collateralAmount = oneHundred_d6;
        uint256 minOut = oneHundred_d18 - ten_d18;

        // Decrease collateral ratio
        priceOracle.setEUSDUSDPrice(1020000);
        pid.refreshCollateralRatio();

        vm.prank(user1);
        vm.expectRevert("Collateral ratio must be >= 1");
        pool_usdc.mint1t1EUSD(collateralAmount, minOut);
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
        pool_usdc.mint1t1EUSD(collateralAmount, minOut);
    }

    function testCannotMintSlippageLimitReached() public {
        uint256 collateralAmount = oneHundred_d6;
        uint256 minOut = 99*(one_d18);

        // Attempt to mint 100eusd when pool ceiling is 10

        priceOracle.setUSDCUSDPrice(980000);
        vm.prank(user1);
        vm.expectRevert("Slippage limit reached");
        pool_usdc.mint1t1EUSD(collateralAmount, minOut);
    }

    // mintFractionalEUSD

    // To mint fractional, we have to set the CR to lower than 1. The way to do that is increasing the market price of EUSD
    // which will result in reduction of the CR.
    function testMintFractionalEUSD() public {
        uint256 collateralAmount = oneHundred_d6;
        uint256 shareAmount = oneHundred_d18;
        uint256 totalToMint = oneHundred_d18;
        uint256 minOut = oneHundred_d18 - ten_d18;
        
        priceOracle.setEUSDUSDPrice((1020000));
        pid.refreshCollateralRatio();
         
        _fundAndApproveShare(user1, address(pool_usdc), shareAmount, shareAmount);

        (uint256 collRequired, uint256 shareRequired) = _calcFractionalParts(totalToMint);

        Balance memory balanceBeforeMint = _getAccountBalance(user1);

        vm.prank(user1);
        pool_usdc.mintFractionalEUSD(collRequired, shareRequired, minOut);
        
        Balance memory balanceAfterMint = _getAccountBalance(user1);

        assertEq(balanceAfterMint.eusd, balanceBeforeMint.eusd + totalToMint);
        assertEq(balanceAfterMint.usdc, balanceBeforeMint.usdc - collRequired);
        assertEq(balanceAfterMint.share, balanceBeforeMint.share - shareRequired);
    }

    function testCannotMintFractionalWhenPaused() public {
        vm.prank(owner);
        pool_usdc.toggleMinting();
        vm.prank(user1);
        vm.expectRevert("Minting is paused");
        pool_usdc.mintFractionalEUSD(PRICE_PRECISION, one_d18, oneHundred_d18 - ten_d18);
    }

    // attempt to mint fractional with CR 100%
    function testCannotMintFractionalWrongCollatRatio() public {

        uint256 usdcAmount = 120*(one_d6);
        uint256 shareAmount = oneHundred_d18;
        uint256 totalToMint = oneHundred_d18;
        uint256 minOut = oneHundred_d18 - ten_d18;
        
        _fundAndApproveShare(user1, address(pool_usdc), shareAmount, shareAmount);

        (uint256 collRequired, uint256 shareRequired) = _calcFractionalParts(totalToMint);
        
        vm.prank(user1);
        vm.expectRevert("Collateral ratio needs to be between .000001 and .999999");
        pool_usdc.mintFractionalEUSD(collRequired, shareRequired, minOut);
    }

    function testCannotMintFractionalWhenPoolCeiling() public {
        uint256 usdcAmount = 120*(one_d6);
        uint256 shareAmount = oneHundred_d18;
        uint256 totalToMint = oneHundred_d18;
        uint256 minOut = oneHundred_d18 - ten_d18;
        
        priceOracle.setEUSDUSDPrice((1020000));
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
        
        _fundAndApproveShare(user1, address(pool_usdc), shareAmount, shareAmount);

        (uint256 collRequired, uint256 shareRequired) = _calcFractionalParts(totalToMint);
        
        vm.prank(user1);
        vm.expectRevert("Pool ceiling reached, no more eusd can be minted with this collateral");
        pool_usdc.mintFractionalEUSD(collRequired, shareRequired, minOut);
    }

    function testCannotMintFractionalSlippage() public {
        uint256 collateralAmount = oneHundred_d6;
        uint256 shareAmount = oneHundred_d18;
        uint256 totalToMint = oneHundred_d18;
        uint256 minOut = 100*(one_d18);
        
        priceOracle.setEUSDUSDPrice((1020000));
        pid.refreshCollateralRatio();
        
        
        _fundAndApproveShare(user1, address(pool_usdc), shareAmount, shareAmount);

        priceOracle.setUSDCUSDPrice(980000);
        priceOracle.setShareUSDPrice(priceOracle.getShareUSDPrice() * 98 / 100);
        
        (uint256 collRequired, uint256 shareRequired) = _calcFractionalParts(totalToMint);
        
        vm.prank(user1);
        vm.expectRevert("Slippage limit reached");
        pool_usdc.mintFractionalEUSD(collRequired, shareRequired, minOut);
    }

    function testCannotMintFractionalNotEnoughShare() public {
        uint256 usdcAmount = oneHundred_d6 + fifty_d6;
        uint256 shareAmount = oneHundred_d18;
        uint256 totalToMint = oneHundred_d18;
        uint256 minOut = oneHundred_d18 - ten_d18;
        
        priceOracle.setEUSDUSDPrice((1020000));
        pid.refreshCollateralRatio();
        
        
        _fundAndApproveShare(user1, address(pool_usdc), shareAmount, shareAmount);

        (uint256 collRequired, uint256 shareRequired) = _calcFractionalParts(totalToMint);
        
        vm.prank(user1);
        vm.expectRevert("Not enough Share inputted");
        pool_usdc.mintFractionalEUSD(collRequired, 0, minOut);   
    }


    // redeem1t1EUSD

    function testRedeem1t1EUSD() public {
        Balance memory balanceBeforeRedeem = _mintEUSD(user1, oneHundred_d6);
        uint256 redeemAmount = fifty_d18;
        uint256 unclaimedPoolCollateralBefore = pool_usdc.unclaimedPoolCollateral();

        vm.startPrank(user1);
        eusd.approve(address(pool_usdc), redeemAmount);
        pool_usdc.redeem1t1EUSD(redeemAmount, ten_d6);
        Balance memory balanceAfterRedeem = _getAccountBalance(user1);

        vm.stopPrank();
        assertEq(balanceAfterRedeem.eusd, balanceBeforeRedeem.eusd - redeemAmount);
        assertEq(pool_usdc.redeemCollateralBalances(user1), fifty_d6);
        assertEq(pool_usdc.unclaimedPoolCollateral(), unclaimedPoolCollateralBefore + fifty_d6);
        assertEq(pool_usdc.lastRedeemed(user1), block.number);
    }

    function testCannotRedeem1t1Paused() public {
        vm.prank(owner);
        pool_usdc.toggleRedeeming();

        vm.expectRevert("Redeeming is paused");
        pool_usdc.redeem1t1EUSD(fifty_d18, ten_d6);
    }

    function testCannotRedeem1t1RatioUnder1() public {
        priceOracle.setEUSDUSDPrice(1020000);
        pid.refreshCollateralRatio();

        vm.expectRevert("Collateral ratio must be == 1");
        pool_usdc.redeem1t1EUSD(fifty_d18, ten_d6);
    }

    function testCannotRedeem1t1NotEnoughColatInPool() public {
        uint256 usdcPoolBalance = usdc.balanceOf(address(pool_usdc));
        vm.prank(address(pool_usdc));
        usdc.transfer(user1, usdcPoolBalance);

        vm.expectRevert("Not enough collateral in pool");
        pool_usdc.redeem1t1EUSD(fifty_d18, ten_d6);
    }

    function testCannotRedeem1t1Slippage() public {
        _mintEUSD(user1, oneHundred_d6);

        priceOracle.setUSDCUSDPrice(1020000);
        
        vm.expectRevert("Slippage limit reached");
        pool_usdc.redeem1t1EUSD(fifty_d18, 495*(10**5));
    }

    /// redeemFractionalEUSD

    function testRedeemFractionalEUSD() public {
         // The fractional minting process reduces the global collateral ratio
        Balance memory balanceBeforeRedeem = _mintFractionalEUSD(user1, oneHundred_d18, 1020000);
        
        uint256 amountToRedeem = balanceBeforeRedeem.eusd / 2;
        (uint256 collPart, uint256 sharePart) = _calculateRedeemingParts(amountToRedeem);

        vm.startPrank(user1);
        eusd.approve(address(pool_usdc), amountToRedeem);
        pool_usdc.redeemFractionalEUSD(amountToRedeem, 0, 0);
        Balance memory balanceAfterRedeem = _getAccountBalance(user1);
        vm.stopPrank();

        assertEq(balanceAfterRedeem.eusd, balanceBeforeRedeem.eusd - amountToRedeem);
        assertEq(pool_usdc.redeemShareBalances(user1), sharePart);
        assertEq(pool_usdc.redeemCollateralBalances(user1), collPart);
    }

    function testCannotRedeemFractionalPaused() public {
        vm.prank(owner);
        pool_usdc.toggleRedeeming();

        vm.expectRevert("Redeeming is paused");
        pool_usdc.redeemFractionalEUSD(oneHundred_d18, 0, 0);
    }

    function testCannotRedeemFractionalWhenCollIs1() public {
        vm.expectRevert("Collateral ratio needs to be between .000001 and .999999");
        pool_usdc.redeemFractionalEUSD(oneHundred_d18, 0, 0);
    }

    function testCannotRedeemFractionalNotEnoughCollat() public {
        priceOracle.setEUSDUSDPrice(1020000);
        pid.refreshCollateralRatio();
        uint256 usdcPoolBalance = usdc.balanceOf(address(pool_usdc));
        vm.prank(address(pool_usdc));
        usdc.transfer(user1, usdcPoolBalance);

        vm.expectRevert("Not enough collateral in pool");
        pool_usdc.redeemFractionalEUSD(oneHundred_d18, 0, 0);
    }

    function testCannotRedeemFractionalSlippage() public {
        _mintFractionalEUSD(user1, oneHundred_d18, 1020000);
        
        priceOracle.setShareUSDPrice(priceOracle.getShareUSDPrice() * 102 / 100);

        // the minting function is putting the collateral ratio on 99.75%, so expected share is pretty low as it is.
        vm.expectRevert("Slippage limit reached [Share]");
        pool_usdc.redeemFractionalEUSD(oneHundred_d18, one_d18, 0);
        
        priceOracle.setUSDCUSDPrice(1020000);

        vm.expectRevert("Slippage limit reached [collateral]");
        pool_usdc.redeemFractionalEUSD(oneHundred_d18, 0, 99*(10**6));
    }

    /// collectRedemption

    function testCollectRedemption() public {
        uint256 originalBlock = block.number;
        testRedeemFractionalEUSD();
        Balance memory userBalanceBeforeCollection = _getAccountBalance(user1);
        uint256 collateralInPool = pool_usdc.redeemCollateralBalances(user1);
        uint256 shareInPool = pool_usdc.redeemShareBalances(user1);

        vm.roll(originalBlock + 5);
        vm.prank(user1);
        pool_usdc.collectRedemption();
        
        Balance memory userBalanceAfterCollection = _getAccountBalance(user1);
        
        assertEq(pool_usdc.redeemCollateralBalances(user1), 0);
        assertEq(userBalanceAfterCollection.share, userBalanceBeforeCollection.share + shareInPool);
        assertEq(userBalanceAfterCollection.usdc, userBalanceBeforeCollection.usdc + collateralInPool);
    }

    function testCannotCollectRedemptionBadDelay() public {
        testRedeemFractionalEUSD();
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

    /// RecollateralizeEUSD
    /// testing recollateralization requires putting the system in a state that will allow it.
    /// The process is straight forward considering the EUSD-USD is 1 USDC-USD is 1
    /// Actual recollat process checks how much collateral is needed to increase the protocol back to the desired CR
    /// and allowed only that amount to be deposited. The depositor receives extra share based on bonus rate.
    function testRecollateralizeEUSD() public {
        _mintEUSD(user1, oneHundred_d6);
        _fundAndApproveUSDC(user1, address(pool_usdc), 1000*(10**6), 1000*(10**6));

        /// remove physical collateral instead of changing the USDC price.
        /// It works the same way since the goal is to have the collateral dollar value lower then what's needed.
        vm.prank(address(pool_usdc));
        usdc.transfer(user1, fifty_d6);

        uint256 poolCollateralBefore = usdc.balanceOf(address(pool_usdc));
        uint256 collateral_amount = fifty_d6;
        uint256 collateral_amount_d18 = collateral_amount * (missing_decimals);
        // calculate the expected share in account to the bonus rate and recollat fee
        uint256 expectedShare = collateral_amount_d18 * (10**6 + pool_usdc.bonus_rate() - pool_usdc.recollat_fee()) / priceOracle.getShareUSDPrice(); 
        Balance memory balanceBeforeRecollat = _getAccountBalance(user1);
        
        vm.prank(user1);
        pool_usdc.recollateralizeEUSD(collateral_amount, 0);

        Balance memory balanceAfterRecollat = _getAccountBalance(user1);
        assertEq(balanceAfterRecollat.share, expectedShare);
        assertEq(balanceAfterRecollat.usdc, balanceBeforeRecollat.usdc - collateral_amount);
        assertEq(usdc.balanceOf(address(pool_usdc)), poolCollateralBefore + collateral_amount);
    }

    function testCannotRecollateralizePaused() public {
        vm.prank(owner);
        pool_usdc.toggleRecollateralize();

        vm.expectRevert("Recollateralize is paused");
        vm.prank(user1);
        pool_usdc.recollateralizeEUSD(oneHundred_d6, 0);
    }

    function testCannotRecollateralizeSlippage() public {
        uint256 collateral_amount = fifty_d6;
        uint256 collateral_amount_d18 = collateral_amount * ( missing_decimals );
        uint256 expectedShare = collateral_amount_d18 * (10**6 + pool_usdc.bonus_rate() - pool_usdc.recollat_fee()) / priceOracle.getShareUSDPrice(); 
        uint256 minShareOut = expectedShare * 99 / 100;
        
        _mintEUSD(user1, oneHundred_d6);
        _fundAndApproveUSDC(user1, address(pool_usdc), 1000*(10**6), 1000*(10**6));

        priceOracle.setShareUSDPrice(priceOracle.getShareUSDPrice() * 102 / 100);
        vm.expectRevert("Slippage limit reached");
        vm.prank(user1);
        pool_usdc.recollateralizeEUSD(collateral_amount, minShareOut);
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
    
    /// buyBackShares

    /// when the system has more collateral value in it than the needed to achieve the exact CR, the protocol will buy share back
    /// and will pay collateral.
    /// The library function checks if there is any excess collateral in the system. if there is, the system allowes buying back
    /// share and give away collateral to reduce the CR back to the desired CR.
    function testBuyBackShares() public {
        uint256 shareAmount = ten_d18;
        uint256 sharePrice = priceOracle.getShareUSDPrice();
        uint256 collPrice = priceOracle.getEUSDUSDPrice();
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

        _fundAndApproveShare(user1, address(pool_usdc), oneHundred_d18, oneHundred_d18);
        priceOracle.setEUSDUSDPrice(1040000);
        pid.refreshCollateralRatio();
        
        // calculated as the dollar amount expected to receive for a deposited share to the protocol
        uint256 expectedCollateral = shareAmount * sharePrice / one_d18 * (10**6 - pool_usdc.buyback_fee()) / 10**6;
            
        Balance memory balanceBeforeBuyBack = _getAccountBalance(user1);
        vm.prank(user1);

        // depositing 10 shares (100$ worth buy share_price = 10e6 althought the actual excess is 250$)
        pool_usdc.buyBackShare(ten_d18, 0);
        Balance memory balanceAfterBuyBack = _getAccountBalance(user1);

        assertEq(balanceAfterBuyBack.usdc, balanceBeforeBuyBack.usdc + expectedCollateral);
        assertEq(balanceAfterBuyBack.share, balanceBeforeBuyBack.share - shareAmount);
    }

    function testCannotBuyBackSharePaused() public {
        vm.prank(owner);
        pool_usdc.toggleBuyBack();

        vm.expectRevert("Buyback is paused");
        vm.prank(user1);
        pool_usdc.buyBackShare(ten_d18, 0);
    }

    // buy back will not pass because the amount of collateral is enough. will revert in library function
    function testCannotBuyBackShareNoExcess() public {
        vm.prank(user1);
        vm.expectRevert("No excess collateral to buy back!");
        pool_usdc.buyBackShare(ten_d18, 0);
    }

    // define a low excess
    // mint 100 means the excess is lower than 1 dollar. therefore anything above the excess will revert in library function
    function testCannotBuyBackShareMoreThanExcess() public {
        uint256 shareAmount = fiveHundred_d18;
        uint256 sharePrice = priceOracle.getShareUSDPrice();
        uint256 collPrice = priceOracle.getEUSDUSDPrice();
        
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

        priceOracle.setEUSDUSDPrice(1060000);
        pid.refreshCollateralRatio();

        vm.stopPrank();
        vm.expectRevert("You are trying to buy back more than the excess!");
        pool_usdc.buyBackShare(shareAmount, 0);
    }

    // function acts same as main test but requires share_min higher than possible in respect to the amounts entered
    function testCannotBuyBackShareSlippage() public {
        uint256 shareAmount = ten_d18;
        uint256 sharePrice = priceOracle.getShareUSDPrice();
        uint256 collPrice = priceOracle.getUSDCUSDPrice();
        uint256 minOut = shareAmount * sharePrice / (10**6) * 99 / 100 / (missing_decimals);
        // _mintEUSD(user1, oneHundred_d6 * 1000);
        
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

        priceOracle.setEUSDUSDPrice(1040000);
        pid.refreshCollateralRatio();

        priceOracle.setUSDCUSDPrice(1020000);
        
        vm.prank(user1);
        vm.expectRevert("Slippage limit reached");
        pool_usdc.buyBackShare(ten_d18, minOut);    
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

    function _calcFractionalParts(uint256 _totalEUSDOut) public returns(uint256 collRequired, uint256 shareRequired) {
        uint256 gcr = pid.global_collateral_ratio();
        uint256 sharePrice = priceOracle.getShareUSDPrice();
        uint256 usdcPrice = priceOracle.getUSDCUSDPrice();
        

        uint256 totalDollarValue = _totalEUSDOut;
        
        uint256 collDollarPortion = (totalDollarValue * gcr) / ( missing_decimals);
        uint256 shareDollarPortion = (totalDollarValue * (PRICE_PRECISION - gcr)) / PRICE_PRECISION; 
        
        collRequired = collDollarPortion / usdcPrice;
        shareRequired = (shareDollarPortion * PRICE_PRECISION) / sharePrice; 
    }

    function _calculateRedeemingParts(uint256 _redeemAmount) private returns(uint256 collateralAmount, uint256 shareAmount){
        uint256 gcr = pid.global_collateral_ratio();
        uint256 sharePrice = priceOracle.getShareUSDPrice();
        uint256 usdcPrice = priceOracle.getUSDCUSDPrice();
        uint256 redemptionFee = pool_usdc.redemption_fee();

        uint256 redeemAmountPostFee = _redeemAmount * (PRICE_PRECISION - redemptionFee) / PRICE_PRECISION;
        uint256 shareDollarValue = redeemAmountPostFee - (redeemAmountPostFee * gcr / PRICE_PRECISION);
        shareAmount = shareDollarValue * PRICE_PRECISION / sharePrice;

        uint256 redeemAmountPrecision = redeemAmountPostFee / (missing_decimals);
        uint256 collDollarValue = redeemAmountPrecision * gcr / PRICE_PRECISION;
        collateralAmount = collDollarValue * PRICE_PRECISION / usdcPrice;
    }

    function _mintEUSD(address _to, uint256 _amountToMint) private returns(Balance memory) {
        _fundAndApproveUSDC(_to, address(pool_usdc), _amountToMint * 2, _amountToMint * 2);
        
        vm.prank(_to);
        pool_usdc.mint1t1EUSD(_amountToMint, _amountToMint * (missing_decimals));
        
        return _getAccountBalance(_to);
    }

    function _mintFractionalEUSD(address _to, uint256 _amountToMint , uint256 _eusdPrice) private returns(Balance memory) {
        uint256 shareAmount = _amountToMint * 10;
        uint256 usdcAmount = _amountToMint / (missing_decimals) * 10;
        
        priceOracle.setEUSDUSDPrice(_eusdPrice);
        pid.refreshCollateralRatio();
        
        
        _fundAndApproveShare(user1, address(pool_usdc), shareAmount, shareAmount);

        (uint256 collRequired, uint256 shareRequired) = _calcFractionalParts(_amountToMint);
        
        vm.prank(user1);
        pool_usdc.mintFractionalEUSD(collRequired, shareRequired, 0);

        return _getAccountBalance(_to);
    }


    // events

    event PoolParametersSet(uint256 new_ceiling, uint256 new_bonus_rate, uint256 new_redemption_delay, uint256 new_mint_fee, uint256 new_redeem_fee, uint256 new_buyback_fee, uint256 new_recollat_fee);
    event TimelockSet(address new_timelock);
    event MintingToggled(bool toggled);
    event RedeemingToggled(bool toggled);
    event RecollateralizeToggled(bool toggled);
    event BuybackToggled(bool toggled);
    event CollateralPriceToggled(bool toggled);
}
