// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseSetup.t.sol";
import "src/contracts/TON.sol";
import "src/contracts/StablecoinDepositModule.sol";

contract StablecoinDepositModuleTest is BaseSetup {
    /// Errors
    error ZeroAddressDetected();
    error CannotRedeemMoreThanDeposited();
    error StablecoinNotWhitelisted();

    /// Events
    event StablecoinWhitelisted(address indexed stablecoin);
    event StablecoinDelisted(address indexed stablecoin);
    event StablecoinDeposited(
        address indexed stablecoin, address indexed depositor, uint256 depositAmount
    );
    event StablecoinRedeemed(
        address indexed stablecoin, address indexed redeemer, uint256 redeemAmount
    );

    StablecoinDepositModule public generalStablecoinDepositModule;

    /// private functions
    function _whitelistCaller(address caller, uint256 ceiling) private {
        vm.prank(owner);
        teller.whitelistCaller(caller, ceiling);
    }

    function setUp() public {
        _whitelistCaller(owner, TEN_THOUSAND_D18);
        _whitelistCaller(user1, ONE_HUNDRED_D18);

        vm.prank(owner);
        generalStablecoinDepositModule = new StablecoinDepositModule(
            address(owner),
            address(teller),
            address(pho)
        );

        // Fund user with USDC
        vm.prank(richGuy);
        usdc.transfer(user1, TEN_THOUSAND_D6);
        // Fund user with DAI
        vm.prank(daiWhale);
        dai.transfer(user1, TEN_THOUSAND_D18);
        // Mint PHO to user
        vm.prank(owner);
        teller.mintPHO(address(user1), ONE_HUNDRED_D18);

        // Approve sending USDC to USDC Deposit contract
        vm.prank(user1);
        usdc.approve(address(generalStablecoinDepositModule), TEN_THOUSAND_D6);
        // Approve sending DAI to DAI Deposit contract
        vm.prank(user1);
        dai.approve(address(generalStablecoinDepositModule), TEN_THOUSAND_D18);

        // Allow sending PHO (redemptions) to each StablecoinDeposit contract
        vm.prank(user1);
        pho.approve(address(generalStablecoinDepositModule), TEN_THOUSAND_D18);
        vm.prank(user1);
        pho.approve(address(generalStablecoinDepositModule), TEN_THOUSAND_D18);

        // Mint PHO to USDC Deposit contract
        vm.prank(owner);
        teller.mintPHO(address(generalStablecoinDepositModule), ONE_THOUSAND_D18);
        // Mint PHO to DAI Deposit contract
        vm.prank(owner);
        teller.mintPHO(address(generalStablecoinDepositModule), ONE_THOUSAND_D18);

        // Whitelist stablecoins
        vm.prank(owner);
        generalStablecoinDepositModule.addStablecoin(address(usdc));
        vm.prank(owner);
        generalStablecoinDepositModule.addStablecoin(address(dai));
    }

    // Cannot set any 0 addresses for constructor
    function testCannotMakeStablecoinDepositModuleWithZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        vm.prank(user1);
        generalStablecoinDepositModule = new StablecoinDepositModule(
            address(0),
            address(teller),
            address(pho)
        );

        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        vm.prank(user1);
        generalStablecoinDepositModule = new StablecoinDepositModule(
            address(owner),
            address(0),
            address(pho)
        );

        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        vm.prank(user1);
        generalStablecoinDepositModule = new StablecoinDepositModule(
            address(owner),
            address(teller),
            address(0)
        );
    }

    // Cannot add to whitelist unless owner
    function testAddToWhitelistOnlyOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(user1);
        generalStablecoinDepositModule.addStablecoin(address(fraxBP));
    }

    // Basic add to whitelist test
    function testAddToWhitelist() public {
        vm.expectEmit(true, true, true, true);
        emit StablecoinWhitelisted(address(fraxBP));
        vm.prank(owner);
        generalStablecoinDepositModule.addStablecoin(address(fraxBP));
        assertEq(generalStablecoinDepositModule.stablecoinWhitelist(address(fraxBP)), true);
    }

    // Cannot remove from whitelist unless owner
    function testRemoveFromWhitelistOnlyOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(user1);
        generalStablecoinDepositModule.removeStablecoin(address(fraxBP));
    }

    // Basic remove from whitelist test
    function testRemoveFromWhitelist() public {
        vm.expectEmit(true, true, true, true);
        emit StablecoinDelisted(address(fraxBP));
        vm.prank(owner);
        generalStablecoinDepositModule.addStablecoin(address(fraxBP));
        vm.prank(owner);
        generalStablecoinDepositModule.removeStablecoin(address(fraxBP));
        assertEq(generalStablecoinDepositModule.stablecoinWhitelist(address(fraxBP)), false);
    }

    // Basic deposit for non-18 decimals
    function testDepositStablecoinUSDC() public {
        uint256 depositAmount = ONE_HUNDRED_D6;
        uint256 expectedIssuedAmount = depositAmount * 10 ** 12;
        // deposit
        vm.expectEmit(true, true, true, true);
        emit StablecoinDeposited(address(usdc), user1, depositAmount);
        vm.prank(user1);
        generalStablecoinDepositModule.depositStablecoin(address(usdc), depositAmount);
        // check expected mint amount
        assertEq(
            generalStablecoinDepositModule.issuedAmount(address(usdc), user1), expectedIssuedAmount
        );
    }

    // Basic deposit for standard 18 decimals
    function testDepositStablecoinDAI() public {
        uint256 depositAmount = ONE_HUNDRED_D18;
        // deposit
        vm.prank(user1);
        generalStablecoinDepositModule.depositStablecoin(address(dai), depositAmount);
        assertEq(generalStablecoinDepositModule.issuedAmount(address(dai), user1), depositAmount);
    }

    // Cannot redeem more than issued
    function testCannotRedeemStablecoinMoreThanIssued() public {
        uint256 depositAmount = ONE_HUNDRED_D6;
        uint256 redeemAmount = depositAmount * 10 ** 12;
        vm.prank(user1);
        generalStablecoinDepositModule.depositStablecoin(address(usdc), depositAmount / 2);
        vm.expectRevert(abi.encodeWithSelector(CannotRedeemMoreThanDeposited.selector));
        vm.prank(user1);
        generalStablecoinDepositModule.redeemStablecoin(address(usdc), redeemAmount);
    }

    // Test basic redeem with non 18 decimals
    function testRedeemStablecoinUSDC() public {
        uint256 depositAmount = ONE_HUNDRED_D6;
        uint256 redeemAmount = depositAmount * 10 ** 12;

        vm.prank(user1);
        generalStablecoinDepositModule.depositStablecoin(address(usdc), depositAmount);

        // USDC and PHO balances before
        uint256 usdcBalanceUserBefore = usdc.balanceOf(address(user1));
        uint256 usdcDepositModuleBalanceBefore =
            usdc.balanceOf(address(generalStablecoinDepositModule));
        uint256 phoBalanceUserBefore = pho.balanceOf(user1);
        uint256 phoDepositBalanceBefore = pho.balanceOf(address(generalStablecoinDepositModule));

        vm.expectEmit(true, true, true, true);
        emit StablecoinRedeemed(address(usdc), user1, redeemAmount);
        vm.prank(user1);
        generalStablecoinDepositModule.redeemStablecoin(address(usdc), redeemAmount);

        // USDC and PHO balances after
        uint256 usdcBalanceUserAfter = usdc.balanceOf(address(user1));
        uint256 usdcDepositModuleBalanceAfter =
            usdc.balanceOf(address(generalStablecoinDepositModule));
        uint256 phoBalanceUserAfter = pho.balanceOf(user1);
        uint256 phoDepositBalanceAfter = pho.balanceOf(address(generalStablecoinDepositModule));

        // Check that DAI and PHO balances before and after are same
        assertEq(usdcBalanceUserAfter, usdcBalanceUserBefore + depositAmount);
        assertEq(usdcDepositModuleBalanceAfter, usdcDepositModuleBalanceBefore - depositAmount);
        assertEq(phoBalanceUserAfter, phoBalanceUserBefore - redeemAmount);
        assertEq(phoDepositBalanceAfter, phoDepositBalanceBefore + redeemAmount);
        assertEq(generalStablecoinDepositModule.issuedAmount(address(usdc), user1), 0);
    }

    // Test basic redeem with standard 18 decimals
    function testRedeemStablecoinDAI() public {
        uint256 depositAmount = ONE_HUNDRED_D18;
        uint256 redeemAmount = ONE_HUNDRED_D18;

        vm.prank(user1);
        generalStablecoinDepositModule.depositStablecoin(address(dai), depositAmount);

        // DAI and PHO balances before
        uint256 daiBalanceUserBefore = dai.balanceOf(address(user1));
        uint256 daiDepositModuleBalanceBefore =
            dai.balanceOf(address(generalStablecoinDepositModule));
        uint256 phoBalanceUserBefore = pho.balanceOf(user1);
        uint256 phoDepositBalanceBefore = pho.balanceOf(address(generalStablecoinDepositModule));

        vm.prank(user1);
        generalStablecoinDepositModule.redeemStablecoin(address(dai), redeemAmount);

        // DAI and PHO balances after
        uint256 daiBalanceUserAfter = dai.balanceOf(address(user1));
        uint256 daiDepositModuleBalanceAfter =
            dai.balanceOf(address(generalStablecoinDepositModule));
        uint256 phoBalanceUserAfter = pho.balanceOf(user1);
        uint256 phoDepositBalanceAfter = pho.balanceOf(address(generalStablecoinDepositModule));

        // Check that DAI and PHO balances before and after are same
        assertEq(daiBalanceUserAfter, daiBalanceUserBefore + depositAmount);
        assertEq(daiDepositModuleBalanceAfter, daiDepositModuleBalanceBefore - depositAmount);
        assertEq(phoBalanceUserAfter, phoBalanceUserBefore - redeemAmount);
        assertEq(phoDepositBalanceAfter, phoDepositBalanceBefore + redeemAmount);

        assertEq(generalStablecoinDepositModule.issuedAmount(address(dai), user1), 0);
    }

    // Functionality is stubbed out for now

    // Cannot mint PHO if not dispatcher
    function testCannotMintPhoOnlyDispatcher() public {
        uint256 amount = ONE_HUNDRED_D18;
        vm.expectRevert("Only dispatcher");
        vm.prank(user1);
        generalStablecoinDepositModule.mintPho(amount);
    }

    // Cannot burn PHO if not dispatcher
    function testCannotMintOnlyDispatcher() public {
        uint256 amount = ONE_HUNDRED_D18;
        vm.expectRevert("Only dispatcher");
        vm.prank(user1);
        generalStablecoinDepositModule.burnPho(amount);
    }
}
