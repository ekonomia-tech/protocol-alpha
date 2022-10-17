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

    StablecoinDepositModule public usdcStablecoinDepositModule;
    StablecoinDepositModule public daiStablecoinDepositModule;

    /// private functions
    function _whitelistCaller(address caller, uint256 ceiling) private {
        vm.prank(owner);
        teller.whitelistCaller(caller, ceiling);
    }

    function setUp() public {
        _whitelistCaller(owner, TEN_THOUSAND_D18);
        _whitelistCaller(user1, ONE_HUNDRED_D18);

        vm.prank(owner);
        usdcStablecoinDepositModule = new StablecoinDepositModule(
            address(owner),
            address(usdc),
            address(teller),
            address(pho)
        );

        vm.prank(owner);
        daiStablecoinDepositModule = new StablecoinDepositModule(
            address(owner),
            address(dai),
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
        usdc.approve(address(usdcStablecoinDepositModule), TEN_THOUSAND_D6);
        // Approve sending DAI to DAI Deposit contract
        vm.prank(user1);
        dai.approve(address(daiStablecoinDepositModule), TEN_THOUSAND_D18);

        // Allow sending PHO (redemptions) to each StablecoinDeposit contract
        vm.prank(user1);
        pho.approve(address(usdcStablecoinDepositModule), TEN_THOUSAND_D18);
        vm.prank(user1);
        pho.approve(address(daiStablecoinDepositModule), TEN_THOUSAND_D18);

        // Mint PHO to USDC Deposit contract
        vm.prank(owner);
        teller.mintPHO(address(usdcStablecoinDepositModule), ONE_THOUSAND_D18);
        // Mint PHO to DAI Deposit contract
        vm.prank(owner);
        teller.mintPHO(address(daiStablecoinDepositModule), ONE_THOUSAND_D18);
    }

    // Cannot set any 0 addresses for constructor
    function testCannotMakeStablecoinDepositModuleWithZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        vm.prank(user1);
        usdcStablecoinDepositModule = new StablecoinDepositModule(
            address(owner),
            address(0),
            address(teller),
            address(pho)
        );

        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        vm.prank(user1);
        usdcStablecoinDepositModule = new StablecoinDepositModule(
            address(owner),
            address(usdc),
            address(0),
            address(pho)
        );

        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        vm.prank(user1);
        usdcStablecoinDepositModule = new StablecoinDepositModule(
            address(owner),
            address(usdc),
            address(teller),
            address(0)
        );
    }

    // Basic deposit for non-18 decimals
    function testDepositStablecoinUSDC() public {
        uint256 depositAmount = ONE_HUNDRED_D6;
        uint256 expectedIssuedAmount = depositAmount * 10 ** 12;
        // deposit
        vm.expectEmit(true, true, true, true);
        emit StablecoinDeposited(address(usdc), user1, depositAmount);
        vm.prank(user1);
        usdcStablecoinDepositModule.depositStablecoin(depositAmount);
        // check expected mint amount
        assertEq(usdcStablecoinDepositModule.issuedAmount(user1), expectedIssuedAmount);
    }

    // Basic deposit for standard 18 decimals
    function testDepositStablecoinDAI() public {
        uint256 depositAmount = ONE_HUNDRED_D18;
        // deposit
        vm.prank(user1);
        daiStablecoinDepositModule.depositStablecoin(depositAmount);
        assertEq(daiStablecoinDepositModule.issuedAmount(user1), depositAmount);
    }

    // Cannot redeem more than issued
    function testCannotRedeemStablecoinMoreThanIssued() public {
        uint256 depositAmount = ONE_HUNDRED_D6;
        uint256 redeemAmount = depositAmount * 10 ** 12;
        vm.prank(user1);
        usdcStablecoinDepositModule.depositStablecoin(depositAmount / 2);
        vm.expectRevert(abi.encodeWithSelector(CannotRedeemMoreThanDeposited.selector));
        vm.prank(user1);
        usdcStablecoinDepositModule.redeemStablecoin(redeemAmount);
    }

    // Test basic redeem with non 18 decimals
    function testRedeemStablecoinUSDC() public {
        uint256 depositAmount = ONE_HUNDRED_D6;
        uint256 redeemAmount = depositAmount * 10 ** 12;

        vm.prank(user1);
        usdcStablecoinDepositModule.depositStablecoin(depositAmount);

        // USDC and PHO balances before
        uint256 usdcBalanceUserBefore = usdc.balanceOf(address(user1));
        uint256 usdcDepositModuleBalanceBefore =
            usdc.balanceOf(address(usdcStablecoinDepositModule));
        uint256 phoBalanceUserBefore = pho.balanceOf(user1);
        uint256 phoDepositBalanceBefore = pho.balanceOf(address(usdcStablecoinDepositModule));

        vm.expectEmit(true, true, true, true);
        emit StablecoinRedeemed(address(usdc), user1, redeemAmount);
        vm.prank(user1);
        usdcStablecoinDepositModule.redeemStablecoin(redeemAmount);

        // USDC and PHO balances after
        uint256 usdcBalanceUserAfter = usdc.balanceOf(address(user1));
        uint256 usdcDepositModuleBalanceAfter = usdc.balanceOf(address(usdcStablecoinDepositModule));
        uint256 phoBalanceUserAfter = pho.balanceOf(user1);
        uint256 phoDepositBalanceAfter = pho.balanceOf(address(usdcStablecoinDepositModule));

        // Check that DAI and PHO balances before and after are same
        assertEq(usdcBalanceUserAfter, usdcBalanceUserBefore + depositAmount);
        assertEq(usdcDepositModuleBalanceAfter, usdcDepositModuleBalanceBefore - depositAmount);
        assertEq(phoBalanceUserAfter, phoBalanceUserBefore - redeemAmount);
        assertEq(phoDepositBalanceAfter, phoDepositBalanceBefore + redeemAmount);
        assertEq(usdcStablecoinDepositModule.issuedAmount(user1), 0);
    }

    // Test basic redeem with standard 18 decimals
    function testRedeemStablecoinDAI() public {
        uint256 depositAmount = ONE_HUNDRED_D18;
        uint256 redeemAmount = ONE_HUNDRED_D18;

        vm.prank(user1);
        daiStablecoinDepositModule.depositStablecoin(depositAmount);

        // DAI and PHO balances before
        uint256 daiBalanceUserBefore = dai.balanceOf(address(user1));
        uint256 daiDepositModuleBalanceBefore = dai.balanceOf(address(daiStablecoinDepositModule));
        uint256 phoBalanceUserBefore = pho.balanceOf(user1);
        uint256 phoDepositBalanceBefore = pho.balanceOf(address(daiStablecoinDepositModule));

        vm.prank(user1);
        daiStablecoinDepositModule.redeemStablecoin(redeemAmount);

        // DAI and PHO balances after
        uint256 daiBalanceUserAfter = dai.balanceOf(address(user1));
        uint256 daiDepositModuleBalanceAfter = dai.balanceOf(address(daiStablecoinDepositModule));
        uint256 phoBalanceUserAfter = pho.balanceOf(user1);
        uint256 phoDepositBalanceAfter = pho.balanceOf(address(daiStablecoinDepositModule));

        // Check that DAI and PHO balances before and after are same
        assertEq(daiBalanceUserAfter, daiBalanceUserBefore + depositAmount);
        assertEq(daiDepositModuleBalanceAfter, daiDepositModuleBalanceBefore - depositAmount);
        assertEq(phoBalanceUserAfter, phoBalanceUserBefore - redeemAmount);
        assertEq(phoDepositBalanceAfter, phoDepositBalanceBefore + redeemAmount);

        assertEq(daiStablecoinDepositModule.issuedAmount(user1), 0);
    }

    // TODO: mint/burn PHO
}
