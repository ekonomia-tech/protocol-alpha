// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

//import "forge-std/console2.sol";
import "../../BaseSetup.t.sol";
import "src/modules/mapleDepositModule/MapleDepositModule.sol";
import "src/modules/mapleDepositModule/IMplRewards.sol";
import "src/protocol/interfaces/IModuleManager.sol";

contract MapleDepositModuleTest is BaseSetup {
    /// Errors
    error ZeroAddressDetected();
    error CannotRedeemMoreThanDeposited();
    error MapleNotWhitelisted();

    /// Events
    event MapleWhitelisted(address indexed maple);
    event MapleDelisted(address indexed maple);
    event MapleDeposited(
        address indexed maple, address indexed depositor, uint256 depositAmount, uint256 phoMinted
    );
    event MapleRedeemed(
        address indexed maple, address indexed redeemer, uint256 redeemAmount, uint256 mplRedeemed
    );

    MapleDepositModule public mapleDepositModule;
    IMplRewards public mplRewards;

    uint256 public moduleDelay;

    function setUp() public {
        // TODO: change this address
        mplRewards = IMplRewards(0xed320Bf569E5F3c4e9313391708ddBFc58e296bb);
        vm.prank(owner);
        mapleDepositModule = new MapleDepositModule(
            address(moduleManager),
            address(mpl),
            address(kernel),
            address(pho),
            address(priceOracle),
            address(mplRewards)
        );

        // Add module to ModuleManager
        vm.prank(PHOGovernance);
        moduleManager.addModule(address(mapleDepositModule));

        // Increase PHO ceilings for modules
        vm.prank(TONGovernance);
        moduleManager.setPHOCeilingForModule(address(mapleDepositModule), ONE_MILLION_D18);
        vm.prank(TONGovernance);
        moduleManager.setPHOCeilingForModule(address(mapleDepositModule), ONE_MILLION_D18);

        moduleDelay = 2 weeks;

        // Fund user with MPL
        vm.prank(mplWhale);
        mpl.transfer(user1, TEN_THOUSAND_D18);

        // Mint PHO to user
        vm.prank(address(moduleManager));
        kernel.mintPHO(address(user1), ONE_HUNDRED_D18);

        // Approve sending MPL to MPL Deposit contract
        vm.prank(user1);
        mpl.approve(address(mapleDepositModule), TEN_THOUSAND_D18);

        // Allow sending PHO (redemptions) to each MapleDeposit contract
        vm.prank(user1);
        pho.approve(address(mapleDepositModule), TEN_THOUSAND_D18);
    }

    // Cannot set any 0 addresses for constructor
    function testCannotMakeMapleDepositModuleWithZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        vm.prank(user1);
        mapleDepositModule = new MapleDepositModule(
            address(0),
            address(mpl),
            address(kernel),
            address(pho),
            address(priceOracle),
            address(mplRewards)
        );

        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        vm.prank(user1);
        mapleDepositModule = new MapleDepositModule(
            address(moduleManager),
            address(0),
            address(kernel),
            address(pho),
            address(priceOracle),
            address(mplRewards)
        );

        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        vm.prank(user1);
        mapleDepositModule = new MapleDepositModule(
            address(moduleManager),
            address(usdc),
            address(0),
            address(pho),
            address(priceOracle),
            address(mplRewards)
        );

        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        vm.prank(user1);
        mapleDepositModule = new MapleDepositModule(
            address(moduleManager),
            address(usdc),
            address(kernel),
            address(0),
            address(priceOracle),
            address(mplRewards)
        );

        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        vm.prank(user1);
        mapleDepositModule = new MapleDepositModule(
            address(moduleManager),
            address(usdc),
            address(kernel),
            address(pho),
            address(0),
            address(mplRewards)
        );

        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        vm.prank(user1);
        mapleDepositModule = new MapleDepositModule(
            address(moduleManager),
            address(usdc),
            address(kernel),
            address(pho),
            address(priceOracle),
            address(0)
        );
    }

    // Basic deposit
    function testDepositMapleDAI() public {
        uint256 depositAmount = ONE_HUNDRED_D18;
        uint256 expectedIssuedAmount = depositAmount * (priceOracle.getMPLPHOPrice() / (10 ** 18));
        // deposit
        vm.expectEmit(true, true, true, true);
        emit MapleDeposited(address(mpl), user1, depositAmount, expectedIssuedAmount);
        vm.prank(user1);
        mapleDepositModule.depositMaple(depositAmount);
        assertEq(mapleDepositModule.issuedAmount(user1), expectedIssuedAmount);
    }

    // Cannot redeem more than issued
    function testCannotRedeemMapleMoreThanIssued() public {
        uint256 depositAmount = ONE_HUNDRED_D18;
        uint256 redeemAmount = depositAmount * (priceOracle.getMPLPHOPrice() / (10 ** 18));
        vm.prank(user1);
        mapleDepositModule.depositMaple(depositAmount / 2);
        vm.expectRevert(abi.encodeWithSelector(CannotRedeemMoreThanDeposited.selector));
        vm.prank(user1);
        mapleDepositModule.redeemMaple(redeemAmount);
    }

    // Test basic redeem
    function testRedeemMaple() public {
        uint256 depositAmount = ONE_HUNDRED_D18;
        uint256 redeemAmount = depositAmount * (priceOracle.getMPLPHOPrice() / (10 ** 18));

        vm.prank(user1);
        mapleDepositModule.depositMaple(depositAmount);

        // DAI and PHO balances before
        uint256 mplBalanceUserBefore = mpl.balanceOf(address(user1));
        uint256 mplDepositModuleBalanceBefore = mpl.balanceOf(address(mapleDepositModule));
        uint256 phoBalanceUserBefore = pho.balanceOf(user1);
        uint256 phoDepositBalanceBefore = pho.balanceOf(address(mapleDepositModule));

        vm.prank(user1);
        mapleDepositModule.redeemMaple(redeemAmount);

        // DAI and PHO balances after
        uint256 mplBalanceUserAfter = mpl.balanceOf(address(user1));
        uint256 mplDepositModuleBalanceAfter = mpl.balanceOf(address(mapleDepositModule));
        uint256 phoBalanceUserAfter = pho.balanceOf(user1);
        uint256 phoDepositBalanceAfter = pho.balanceOf(address(mapleDepositModule));

        // Check that DAI and PHO balances before and after are same
        assertEq(mplBalanceUserAfter, mplBalanceUserBefore + depositAmount);
        assertEq(mplDepositModuleBalanceAfter, mplDepositModuleBalanceBefore - depositAmount);
        assertEq(phoBalanceUserAfter, phoBalanceUserBefore - redeemAmount);
        assertEq(phoDepositBalanceAfter, phoDepositBalanceBefore + redeemAmount);

        assertEq(mapleDepositModule.issuedAmount(user1), 0);
    }
}
