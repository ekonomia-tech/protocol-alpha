// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/contracts/Share.sol";
import "src/contracts/Pool.sol";
import "src/contracts/EUSD.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "src/oracle/DummyOracle.sol";
import "src/contracts/PIDController.sol";
import "test/Helper.t.sol";
import {PoolLibrary} from "src/libraries/PoolLibrary.sol";

contract PoolTest is Test, Helper {

    Share public share;
    EUSD public eusd;
    PIDController public pid;
    Pool public pool_usdc;
    DummyOracle public priceOracle;
    ERC20 public usdc;

    address public owner;
    address public randomAccount1 = 0x701ded139b267F9Df781700Eb97337B07cFdDdd8;
    address public randomAccount2 = 0xDc516b17761a2521993823b1f1d274aD90B29E1d;
    address public richGuy = 0x72A53cDBBcc1b9efa39c834A540550e23463AAcB;

    address public constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint256 public constant POOL_CEILING = (2 ** 256) - 1; 
    uint256 public constant PRICE_PRECISION = 10**6;

    uint256 private immutable missing_decimals = 12;

    struct Balance {
        uint256 usdc;
        uint256 eusd;
        uint256 share;
    }

    function setUp() public {
        vm.startPrank(msg.sender);
        owner = msg.sender;
        priceOracle = new DummyOracle();
        eusd = new EUSD("EUSD", "EUSD", owner, owner);
        share = new Share("Share", "SHARE",owner, owner);
        pid = new PIDController(address(eusd), owner, owner, address(priceOracle));
        share.setEUSDAddress(address(eusd)); 
        usdc = ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        pool_usdc = new Pool(address(eusd), address(share), address(pid), USDC_ADDRESS, owner, address(priceOracle), POOL_CEILING);
        eusd.addPool(address(pool_usdc));
        vm.stopPrank();
    }

    /// mint1t1EUSD

    function testMint1t1EUSD() public {
        uint256 collateralAmount = 100*(10**6);
        uint256 minOut = 90*(10**18);
        uint256 expectedOut = collateralAmount * (10 ** 12);

        _fundAndApproveUSDC(randomAccount1, address(pool_usdc), collateralAmount, collateralAmount);
        
        Balance memory balanceBeforeMint = _getAccountBalance(randomAccount1);
        vm.prank(randomAccount1);
        pool_usdc.mint1t1EUSD(collateralAmount, minOut);
        
        assertEq(eusd.balanceOf(randomAccount1), expectedOut);
        assertEq(usdc.balanceOf(randomAccount1), balanceBeforeMint.usdc - collateralAmount);
    }

    function testCannotMintIfFractional() public {
        uint256 collateralAmount = 100*(10**6);
        uint256 minOut = 90*(10**18);

       _fundAndApproveUSDC(randomAccount1, address(pool_usdc), collateralAmount, collateralAmount);
        
        // Decrease collateral ratio
        priceOracle.setEUSDUSDPrice(1020000);
        pid.refreshCollateralRatio();

        vm.prank(randomAccount1);
        vm.expectRevert("Collateral ratio must be >= 1");
        pool_usdc.mint1t1EUSD(collateralAmount, minOut);
    }

    function testCannotMintIfCeilingReached() public {
        uint256 collateralAmount = 100*(10**6);
        uint256 minOut = 90*(10**18);

       _fundAndApproveUSDC(randomAccount1, address(pool_usdc), collateralAmount, collateralAmount);

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

        vm.prank(randomAccount1);
        vm.expectRevert("[Pool's Closed]: Ceiling reached");
        pool_usdc.mint1t1EUSD(collateralAmount, minOut);
    }

    function testCannotMintSlippageLimitReached() public {
        uint256 collateralAmount = 100*(10**6);
        uint256 minOut = 99*(10**18);

       _fundAndApproveUSDC(randomAccount1, address(pool_usdc), collateralAmount, collateralAmount);

        // Attempt to mint 100eusd when pool ceiling is 10

        priceOracle.setUSDCUSDPrice(980000);
        vm.prank(randomAccount1);
        vm.expectRevert("Slippage limit reached");
        pool_usdc.mint1t1EUSD(collateralAmount, minOut);
    }

    // mintFractionalEUSD

    // To mint fractional, we have to set the CR to lower than 1. The way to do that is increasing the market price of EUSD
    // which will result in reduction of the CR.
    function testMintFractionalEUSD() public {
        uint256 collateralAmount = ONE_HUNDRED_d6;
        uint256 shareAmount = ONE_HUNDRED_d18;
        uint256 totalToMint = ONE_HUNDRED_d18;
        uint256 minOut = 90*(10**18);
        
        priceOracle.setEUSDUSDPrice((1020000));
        pid.refreshCollateralRatio();
        
        _fundAndApproveUSDC(randomAccount1, address(pool_usdc), collateralAmount, collateralAmount);
        _fundAndApproveShare(randomAccount1, address(pool_usdc), shareAmount, shareAmount);

        (uint256 collRequired, uint256 shareRequired) = _calcFractionalParts(totalToMint);
        
        vm.prank(randomAccount1);
        pool_usdc.mintFractionalEUSD(collRequired, shareRequired, minOut);
        
        Balance memory balanceAfterMint = _getAccountBalance(randomAccount1);
        assertEq(balanceAfterMint.eusd, totalToMint);
        assertEq(balanceAfterMint.usdc, collateralAmount - collRequired);
        assertEq(balanceAfterMint.share, shareAmount - shareRequired);
    }

    function testCannotMintFractionalWhenPaused() public {
        vm.prank(owner);
        pool_usdc.toggleMinting();
        vm.prank(randomAccount1);
        vm.expectRevert("Minting is paused");
        pool_usdc.mintFractionalEUSD(PRICE_PRECISION, 10**18, 90*(10**18));
    }

    // attempt to mint fractional with CR 100%
    function testCannotMintFractionalWrongCollatRatio() public {

        uint256 usdcAmount = 120*(10**6);
        uint256 shareAmount = ONE_HUNDRED_d18;
        uint256 totalToMint = ONE_HUNDRED_d18;
        uint256 minOut = 90*(10**18);
        
        _fundAndApproveUSDC(randomAccount1, address(pool_usdc), usdcAmount, usdcAmount);
        _fundAndApproveShare(randomAccount1, address(pool_usdc), shareAmount, shareAmount);

        (uint256 collRequired, uint256 shareRequired) = _calcFractionalParts(totalToMint);
        
        vm.prank(randomAccount1);
        vm.expectRevert("Collateral ratio needs to be between .000001 and .999999");
        pool_usdc.mintFractionalEUSD(collRequired, shareRequired, minOut);
    }

    function testCannotMintFractionalWhenPoolCeiling() public {
        uint256 usdcAmount = 120*(10**6);
        uint256 shareAmount = ONE_HUNDRED_d18;
        uint256 totalToMint = ONE_HUNDRED_d18;
        uint256 minOut = 90*(10**18);
        
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

        _fundAndApproveUSDC(randomAccount1, address(pool_usdc), usdcAmount, usdcAmount);
        _fundAndApproveShare(randomAccount1, address(pool_usdc), shareAmount, shareAmount);

        (uint256 collRequired, uint256 shareRequired) = _calcFractionalParts(totalToMint);
        
        vm.prank(randomAccount1);
        vm.expectRevert("Pool ceiling reached, no more eusd can be minted with this collateral");
        pool_usdc.mintFractionalEUSD(collRequired, shareRequired, minOut);
    }

    function testCannotMintFractionalSlippage() public {
        uint256 collateralAmount = ONE_HUNDRED_d6;
        uint256 shareAmount = ONE_HUNDRED_d18;
        uint256 totalToMint = ONE_HUNDRED_d18;
        uint256 minOut = 100*(10**18);
        
        priceOracle.setEUSDUSDPrice((1020000));
        pid.refreshCollateralRatio();
        
        _fundAndApproveUSDC(randomAccount1, address(pool_usdc), collateralAmount, collateralAmount);
        _fundAndApproveShare(randomAccount1, address(pool_usdc), shareAmount, shareAmount);

        priceOracle.setUSDCUSDPrice(980000);
        priceOracle.setShareUSDPrice(priceOracle.getShareUSDPrice() * 98 / 100);
        
        (uint256 collRequired, uint256 shareRequired) = _calcFractionalParts(totalToMint);
        
        vm.prank(randomAccount1);
        vm.expectRevert("Slippage limit reached");
        pool_usdc.mintFractionalEUSD(collRequired, shareRequired, minOut);
    }

    function testCannotMintFractionalNotEnoughShare() public {
        uint256 usdcAmount = ONE_HUNDRED_d6 + TWENTY_FIVE_d6;
        uint256 shareAmount = ONE_HUNDRED_d18;
        uint256 totalToMint = ONE_HUNDRED_d18;
        uint256 minOut = ONE_HUNDRED_d18 - TEN_d18;
        
        priceOracle.setEUSDUSDPrice((1020000));
        pid.refreshCollateralRatio();
        
        _fundAndApproveUSDC(randomAccount1, address(pool_usdc), usdcAmount, usdcAmount);
        _fundAndApproveShare(randomAccount1, address(pool_usdc), shareAmount, shareAmount);

        (uint256 collRequired, uint256 shareRequired) = _calcFractionalParts(totalToMint);
        
        vm.prank(randomAccount1);
        vm.expectRevert("Not enough Share inputted");
        pool_usdc.mintFractionalEUSD(collRequired, 0, minOut);   
    }


    // redeem1t1EUSD

    function testRedeem1t1EUSD() public {
        Balance memory balanceBeforeRedeem = _mintEUSD(randomAccount1, ONE_HUNDRED_d6);
        uint256 redeemAmount = FIFTY_d18;
        uint256 unclaimedPoolCollateralBefore = pool_usdc.unclaimedPoolCollateral();

        vm.startPrank(randomAccount1);
        eusd.approve(address(pool_usdc), redeemAmount);
        pool_usdc.redeem1t1EUSD(redeemAmount, TEN_d6);
        Balance memory balanceAfterRedeem = _getAccountBalance(randomAccount1);

        vm.stopPrank();
        assertEq(balanceAfterRedeem.eusd, balanceBeforeRedeem.eusd - redeemAmount);
        assertEq(pool_usdc.redeemCollateralBalances(randomAccount1), FIFTY_d6);
        assertEq(pool_usdc.unclaimedPoolCollateral(), unclaimedPoolCollateralBefore + FIFTY_d6);
        assertEq(pool_usdc.lastRedeemed(randomAccount1), block.number);
    }

    function testCannotRedeem1t1Paused() public {
        vm.prank(owner);
        pool_usdc.toggleRedeeming();

        vm.expectRevert("Redeeming is paused");
        pool_usdc.redeem1t1EUSD(FIFTY_d18, TEN_d6);
    }

    function testCannotRedeem1t1RatioUnder1() public {
        priceOracle.setEUSDUSDPrice(1020000);
        pid.refreshCollateralRatio();

        vm.expectRevert("Collateral ratio must be == 1");
        pool_usdc.redeem1t1EUSD(FIFTY_d18, TEN_d6);
    }

    function testCannotRedeem1t1NotEnoughColatInPool() public {
        uint256 usdcPoolBalance = usdc.balanceOf(address(pool_usdc));
        vm.prank(address(pool_usdc));
        usdc.transfer(randomAccount1, usdcPoolBalance);

        vm.expectRevert("Not enough collateral in pool");
        pool_usdc.redeem1t1EUSD(FIFTY_d18, TEN_d6);
    }

    function testCannotRedeem1t1Slippage() public {
        _mintEUSD(randomAccount1, ONE_HUNDRED_d6);

        priceOracle.setUSDCUSDPrice(1020000);
        
        vm.expectRevert("Slippage limit reached");
        pool_usdc.redeem1t1EUSD(FIFTY_d18, 495*(10**5));
    }

    /// redeemFractionalEUSD

    function testRedeemFractionalEUSD() public {
         // The fractional minting process reduces the global collateral ratio
        Balance memory balanceBeforeRedeem = _mintFractionalEUSD(randomAccount1, ONE_HUNDRED_d18, 1020000);
        
        uint256 amountToRedeem = balanceBeforeRedeem.eusd / 2;
        (uint256 collPart, uint256 sharePart) = _calculateRedeemingParts(amountToRedeem);

        vm.startPrank(randomAccount1);
        eusd.approve(address(pool_usdc), amountToRedeem);
        pool_usdc.redeemFractionalEUSD(amountToRedeem, 0, 0);
        Balance memory balanceAfterRedeem = _getAccountBalance(randomAccount1);
        vm.stopPrank();

        assertEq(balanceAfterRedeem.eusd, balanceBeforeRedeem.eusd - amountToRedeem);
        assertEq(pool_usdc.redeemShareBalances(randomAccount1), sharePart);
        assertEq(pool_usdc.redeemCollateralBalances(randomAccount1), collPart);
    }

    function testCannotRedeemFractionalPaused() public {
        vm.prank(owner);
        pool_usdc.toggleRedeeming();

        vm.expectRevert("Redeeming is paused");
        pool_usdc.redeemFractionalEUSD(ONE_HUNDRED_d18, 0, 0);
    }

    function testCannotRedeemFractionalWhenCollIs1() public {
        vm.expectRevert("Collateral ratio needs to be between .000001 and .999999");
        pool_usdc.redeemFractionalEUSD(ONE_HUNDRED_d18, 0, 0);
    }

    function testCannotRedeemFractionalNotEnoughCollat() public {
        priceOracle.setEUSDUSDPrice(1020000);
        pid.refreshCollateralRatio();
        uint256 usdcPoolBalance = usdc.balanceOf(address(pool_usdc));
        vm.prank(address(pool_usdc));
        usdc.transfer(randomAccount1, usdcPoolBalance);

        vm.expectRevert("Not enough collateral in pool");
        pool_usdc.redeemFractionalEUSD(ONE_HUNDRED_d18, 0, 0);
    }

    function testCannotRedeemFractionalSlippage() public {
        _mintFractionalEUSD(randomAccount1, ONE_HUNDRED_d18, 1020000);
        
        priceOracle.setShareUSDPrice(priceOracle.getShareUSDPrice() * 102 / 100);

        // the minting function is putting the collateral ratio on 99.75%, so expected share is pretty low as it is.
        vm.expectRevert("Slippage limit reached [Share]");
        pool_usdc.redeemFractionalEUSD(ONE_HUNDRED_d18, 10**18, 0);
        
        priceOracle.setUSDCUSDPrice(1020000);

        vm.expectRevert("Slippage limit reached [collateral]");
        pool_usdc.redeemFractionalEUSD(ONE_HUNDRED_d18, 0, 99*(10**6));
    }

    /// collectRedemption

    function testCollectRedemption() public {
        uint256 originalBlock = block.number;
        testRedeemFractionalEUSD();
        Balance memory userBalanceBeforeCollection = _getAccountBalance(randomAccount1);
        uint256 collateralInPool = pool_usdc.redeemCollateralBalances(randomAccount1);
        uint256 shareInPool = pool_usdc.redeemShareBalances(randomAccount1);

        vm.roll(originalBlock + 5);
        vm.prank(randomAccount1);
        pool_usdc.collectRedemption();
        
        Balance memory userBalanceAfterCollection = _getAccountBalance(randomAccount1);
        
        assertEq(pool_usdc.redeemCollateralBalances(randomAccount1), 0);
        assertEq(userBalanceAfterCollection.share, userBalanceBeforeCollection.share + shareInPool);
        assertEq(userBalanceAfterCollection.usdc, userBalanceBeforeCollection.usdc + collateralInPool);
    }

    function testCannotCollectRedemptionBadDelay() public {
        testRedeemFractionalEUSD();
        vm.prank(randomAccount1);
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
        vm.prank(randomAccount1);
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
        vm.prank(randomAccount1);
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
        vm.prank(randomAccount1);
        pool_usdc.toggleCollateralPrice(0);
    }

    /// RecollateralizeEUSD
    /// testing recollateralization requires putting the system in a state that will allow it.
    /// The process is straight forward considering the EUSD-USD is 1 USDC-USD is 1
    /// Actual recollat process checks how much collateral is needed to increase the protocol back to the desired CR
    /// and allowed only that amount to be deposited. The depositor receives extra share based on bonus rate.
    function testRecollateralizeEUSD() public {
        _mintEUSD(randomAccount1, ONE_HUNDRED_d6);
        _fundAndApproveUSDC(randomAccount1, address(pool_usdc), 1000*(10**6), 1000*(10**6));

        /// remove physical collateral instead of changing the USDC price.
        /// It works the same way since the goal is to have the collateral dollar value lower then what's needed.
        vm.prank(address(pool_usdc));
        usdc.transfer(randomAccount1, FIFTY_d6);

        uint256 poolCollateralBefore = usdc.balanceOf(address(pool_usdc));
        uint256 collateral_amount = FIFTY_d6;
        uint256 collateral_amount_d18 = collateral_amount * (10 ** missing_decimals);
        // calculate the expected share in account to the bonus rate and recollat fee
        uint256 expectedShare = collateral_amount_d18 * (10**6 + pool_usdc.bonus_rate() - pool_usdc.recollat_fee()) / priceOracle.getShareUSDPrice(); 
        Balance memory balanceBeforeRecollat = _getAccountBalance(randomAccount1);
        
        vm.prank(randomAccount1);
        pool_usdc.recollateralizeEUSD(collateral_amount, 0);

        Balance memory balanceAfterRecollat = _getAccountBalance(randomAccount1);
        assertEq(balanceAfterRecollat.share, expectedShare);
        assertEq(balanceAfterRecollat.usdc, balanceBeforeRecollat.usdc - collateral_amount);
        assertEq(usdc.balanceOf(address(pool_usdc)), poolCollateralBefore + collateral_amount);
    }

    function testCannotRecollateralizePaused() public {
        vm.prank(owner);
        pool_usdc.toggleRecollateralize();

        vm.expectRevert("Recollateralize is paused");
        vm.prank(randomAccount1);
        pool_usdc.recollateralizeEUSD(ONE_HUNDRED_d6, 0);
    }

    function testCannotRecollateralizeSlippage() public {
        uint256 collateral_amount = FIFTY_d6;
        uint256 collateral_amount_d18 = collateral_amount * ( 10 ** missing_decimals );
        uint256 expectedShare = collateral_amount_d18 * (10**6 + pool_usdc.bonus_rate() - pool_usdc.recollat_fee()) / priceOracle.getShareUSDPrice(); 
        uint256 minShareOut = expectedShare * 99 / 100;
        
        _mintEUSD(randomAccount1, ONE_HUNDRED_d6);
        _fundAndApproveUSDC(randomAccount1, address(pool_usdc), 1000*(10**6), 1000*(10**6));

        priceOracle.setShareUSDPrice(priceOracle.getShareUSDPrice() * 102 / 100);
        vm.expectRevert("Slippage limit reached");
        vm.prank(randomAccount1);
        pool_usdc.recollateralizeEUSD(collateral_amount, minShareOut);
    }

    function testToggleRecollateralize() public {
        vm.expectEmit(true, false, false, false);
        emit RecollateralizeToggled(true);
        vm.prank(owner);
        pool_usdc.toggleRecollateralize();
    }

    function testFailToggleRecollateralizeUnauthorized() public {
        vm.prank(randomAccount1);
        pool_usdc.toggleRecollateralize();
    }
    
    /// buyBackShares

    /// when the system has more collateral value in it than the needed to achieve the exact CR, the protocol will buy share back
    /// and will pay collateral.
    /// The library function checks if there is any excess collateral in the system. if there is, the system allowes buying back
    /// share and give away collateral to reduce the CR back to the desired CR.
    function testBuyBackShares() public {
        uint256 shareAmount = TEN_d18;
        uint256 sharePrice = priceOracle.getShareUSDPrice();
        uint256 collPrice = priceOracle.getEUSDUSDPrice();
        // Fill the pool with collateral (must be a large amount that will correspond to a single step under %100 collateralization)
        // The lower the CR, the higher the excess amount will be with the same amounts.
        _mintEUSD(randomAccount1, ONE_HUNDRED_d6 * 1000);
        
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

        _fundAndApproveShare(randomAccount1, address(pool_usdc), ONE_HUNDRED_d18, ONE_HUNDRED_d18);
        priceOracle.setEUSDUSDPrice(1040000);
        pid.refreshCollateralRatio();
        
        // calculated as the dollar amount expected to receive for a deposited share to the protocol
        uint256 expectedCollateral = shareAmount * sharePrice / 10**18 * (10**6 - pool_usdc.buyback_fee()) / 10**6;
            
        Balance memory balanceBeforeBuyBack = _getAccountBalance(randomAccount1);
        vm.prank(randomAccount1);

        // depositing 10 shares (100$ worth buy share_price = 10e6 althought the actual excess is 250$)
        pool_usdc.buyBackShare(TEN_d18, 0);
        Balance memory balanceAfterBuyBack = _getAccountBalance(randomAccount1);

        assertEq(balanceAfterBuyBack.usdc, balanceBeforeBuyBack.usdc + expectedCollateral);
        assertEq(balanceAfterBuyBack.share, balanceBeforeBuyBack.share - shareAmount);
    }

    function testCannotBuyBackSharePaused() public {
        vm.prank(owner);
        pool_usdc.toggleBuyBack();

        vm.expectRevert("Buyback is paused");
        vm.prank(randomAccount1);
        pool_usdc.buyBackShare(TEN_d18, 0);
    }

    // buy back will not pass because the amount of collateral is enough. will revert in library function
    function testCannotBuyBackShareNoExcess() public {
        vm.prank(randomAccount1);
        vm.expectRevert("No excess collateral to buy back!");
        pool_usdc.buyBackShare(TEN_d18, 0);
    }

    // define a low excess
    // mint 100 means the excess is lower than 1 dollar. therefore anything above the excess will revert in library function
    function testCannotBuyBackShareMoreThanExcess() public {
        uint256 shareAmount = TEN_d18;
        uint256 sharePrice = priceOracle.getShareUSDPrice();
        uint256 collPrice = priceOracle.getEUSDUSDPrice();
        _mintEUSD(randomAccount1, ONE_HUNDRED_d6);
        
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

        priceOracle.setEUSDUSDPrice(1040000);
        pid.refreshCollateralRatio();

        vm.stopPrank();
        vm.expectRevert("You are trying to buy back more than the excess!");
        pool_usdc.buyBackShare(TEN_d18, 0);
    }

    // function acts same as main test but requires share_min higher than possible in respect to the amounts entered
    function testCannotBuyBackShareSlippage() public {
        uint256 shareAmount = TEN_d18;
        uint256 sharePrice = priceOracle.getShareUSDPrice();
        uint256 collPrice = priceOracle.getUSDCUSDPrice();
        uint256 minOut = shareAmount * sharePrice / (10**6) * 99 / 100 / (10** missing_decimals);
        _mintEUSD(randomAccount1, ONE_HUNDRED_d6 * 1000);
        
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
        
        vm.prank(randomAccount1);
        vm.expectRevert("Slippage limit reached");
        pool_usdc.buyBackShare(TEN_d18, minOut);    
    }


    function testToggleBuyBack() public {
        vm.expectEmit(true, false, false, false);
        emit BuybackToggled(true);
        vm.prank(owner);
        pool_usdc.toggleBuyBack();
    }

    function testFailToggleBuybackUnauthorized() public {
        vm.prank(randomAccount1);
        pool_usdc.toggleBuyBack();
    }
    
    /// Helpers

    function _getUSDC(address to, uint256 _amount) private {
        vm.prank(richGuy);
        usdc.transfer(to, _amount);
    }

    function _approveUSDC(address _owner, address _spender, uint256 _amount) private {
        vm.prank(_owner);
        usdc.approve(_spender, _amount);
    }

    function _fundAndApproveUSDC(address _owner, address _spender, uint256 _amountIn, uint256 _amountOut) private {
        _getUSDC(_owner, _amountIn);
        _approveUSDC(_owner, _spender, _amountOut);
    }

    function _getShare(address _to, uint256 _amount) private {
        vm.prank(address(pool_usdc));
        share.mint(_to, _amount);
    }

    function _approveShare(address _owner, address _spender, uint256 _amount) private {
        vm.prank(_owner);
        share.approve(_spender, _amount);
    }

    function _fundAndApproveShare(address _owner, address _spender, uint256 _amountIn, uint256 _amountOut) private {
        _getShare(_owner, _amountIn);
        _approveShare(_owner, _spender, _amountOut);
    }

    function _calcFractionalParts(uint256 _totalEUSDOut) public returns(uint256 collRequired, uint256 shareRequired) {
        uint256 gcr = pid.global_collateral_ratio();
        uint256 sharePrice = priceOracle.getShareUSDPrice();
        uint256 usdcPrice = priceOracle.getUSDCUSDPrice();
        

        uint256 totalDollarValue = _totalEUSDOut;
        
        uint256 collDollarPortion = (totalDollarValue * gcr) / ( 10 ** missing_decimals);
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

        uint256 redeemAmountPrecision = redeemAmountPostFee / (10 ** missing_decimals);
        uint256 collDollarValue = redeemAmountPrecision * gcr / PRICE_PRECISION;
        collateralAmount = collDollarValue * PRICE_PRECISION / usdcPrice;
    }

    function _mintEUSD(address _to, uint256 _amountToMint) private returns(Balance memory) {
        _fundAndApproveUSDC(_to, address(pool_usdc), _amountToMint * 2, _amountToMint * 2);
        
        vm.prank(_to);
        pool_usdc.mint1t1EUSD(_amountToMint, _amountToMint * (10 ** missing_decimals));
        
        return _getAccountBalance(_to);
    }

    function _mintFractionalEUSD(address _to, uint256 _amountToMint , uint256 _eusdPrice) private returns(Balance memory) {
        uint256 shareAmount = _amountToMint * 10;
        uint256 usdcAmount = _amountToMint / (10 ** missing_decimals) * 10;
        
        priceOracle.setEUSDUSDPrice(_eusdPrice);
        pid.refreshCollateralRatio();
        
        _fundAndApproveUSDC(randomAccount1, address(pool_usdc), usdcAmount, usdcAmount);
        _fundAndApproveShare(randomAccount1, address(pool_usdc), shareAmount, shareAmount);

        (uint256 collRequired, uint256 shareRequired) = _calcFractionalParts(_amountToMint);
        
        vm.prank(randomAccount1);
        pool_usdc.mintFractionalEUSD(collRequired, shareRequired, 0);

        return _getAccountBalance(_to);
    }

    function _getAccountBalance(address _account) private returns(Balance memory) {
        uint256 usdcBalance = usdc.balanceOf(_account);
        uint256 eusdBalance = eusd.balanceOf(_account);
        uint256 shareBalance = share.balanceOf(_account);

        return Balance(usdcBalance, eusdBalance, shareBalance);
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
