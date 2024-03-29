// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../BaseSetup.t.sol";
import "@modules/stablecoinDepositModule/StablecoinDepositModule.sol";
import "@protocol/interfaces/IModuleManager.sol";

contract StablecoinDepositModuleTest is BaseSetup {
    /// Errors
    error ZeroAddressDetected();
    error CannotRedeemMoreThanDeposited();
    error OverEighteenDecimals();

    /// Events
    event StablecoinDeposited(address indexed depositor, uint256 depositAmount);
    event PHORedeemed(address indexed redeemer, uint256 redeemAmount);

    // Track balance for stablecoins and PHO
    struct StablecoinBalance {
        uint256 userStablecoinBalance;
        uint256 moduleStablecoinBalance;
        uint256 userPHOBalance;
        uint256 userIssuedAmount;
        uint256 totalPHOSupply;
    }

    StablecoinDepositModule public usdcStablecoinDepositModule;
    StablecoinDepositModule public daiStablecoinDepositModule;

    uint256 public moduleDelay;

    function setUp() public {
        vm.prank(owner);
        usdcStablecoinDepositModule = new StablecoinDepositModule(
            address(moduleManager),
            address(usdc),
            address(kernel),
            address(pho)
        );

        vm.prank(owner);
        daiStablecoinDepositModule = new StablecoinDepositModule(
            address(moduleManager),
            address(dai),
            address(kernel),
            address(pho)
        );

        // Add module to ModuleManager
        vm.prank(address(PHOTimelock));
        moduleManager.addModule(address(usdcStablecoinDepositModule));
        vm.prank(address(PHOTimelock));
        moduleManager.addModule(address(daiStablecoinDepositModule));

        // Increase PHO ceilings for modules
        vm.prank(address(TONTimelock));
        moduleManager.setPHOCeilingForModule(address(usdcStablecoinDepositModule), ONE_MILLION_D18);
        vm.prank(address(TONTimelock));
        moduleManager.setPHOCeilingForModule(address(daiStablecoinDepositModule), ONE_MILLION_D18);

        moduleDelay = moduleManager.moduleDelay();

        vm.warp(block.timestamp + moduleDelay);
        moduleManager.executeCeilingUpdate(address(usdcStablecoinDepositModule));
        moduleManager.executeCeilingUpdate(address(daiStablecoinDepositModule));

        // Fund user with USDC
        vm.prank(richGuy);
        usdc.transfer(user1, TEN_THOUSAND_D6);
        // Fund user with DAI
        vm.prank(daiWhale);
        dai.transfer(user1, TEN_THOUSAND_D18);
        // Mint PHO to user
        vm.prank(address(moduleManager));
        kernel.mintPHO(address(user1), ONE_HUNDRED_D18);

        // Approve sending USDC to USDC Deposit contract
        vm.startPrank(user1);
        usdc.approve(address(usdcStablecoinDepositModule), TEN_THOUSAND_D6);
        // Approve sending DAI to DAI Deposit contract
        dai.approve(address(daiStablecoinDepositModule), TEN_THOUSAND_D18);

        // Allow sending PHO (redemptions) to each StablecoinDeposit contract
        pho.approve(address(usdcStablecoinDepositModule), TEN_THOUSAND_D18);
        pho.approve(address(daiStablecoinDepositModule), TEN_THOUSAND_D18);

        // Approve PHO burnFrom() via moduleManager calling kernel
        pho.approve(address(kernel), ONE_MILLION_D18);
        vm.stopPrank();
    }

    // Cannot set any 0 addresses for constructor
    function testCannotMakeStablecoinDepositModuleWithZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        vm.prank(user1);
        usdcStablecoinDepositModule = new StablecoinDepositModule(
            address(0),
            address(usdc),
            address(kernel),
            address(pho)
        );

        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        vm.prank(user1);
        usdcStablecoinDepositModule = new StablecoinDepositModule(
            address(moduleManager),
            address(0),
            address(kernel),
            address(pho)
        );

        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        vm.prank(user1);
        usdcStablecoinDepositModule = new StablecoinDepositModule(
            address(moduleManager),
            address(usdc),
            address(0),
            address(pho)
        );

        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        vm.prank(user1);
        usdcStablecoinDepositModule = new StablecoinDepositModule(
            address(moduleManager),
            address(usdc),
            address(kernel),
            address(0)
        );
    }

    // Basic deposit for non-18 decimals
    function testDepositStablecoinUSDC() public {
        uint256 depositAmount = ONE_HUNDRED_D6;
        _testDepositAnyModule(depositAmount, usdcStablecoinDepositModule);
    }

    // Basic deposit for standard 18 decimals
    function testDepositStablecoinDAI() public {
        uint256 depositAmount = ONE_HUNDRED_D18;
        _testDepositAnyModule(depositAmount, daiStablecoinDepositModule);
    }

    // Private function to test Stablecoin deposit from any module
    function _testDepositAnyModule(uint256 _depositAmount, StablecoinDepositModule _module)
        public
    {
        // Convert expected issue amount based on stablecoin decimals
        uint256 expectedIssuedAmount =
            _depositAmount * 10 ** (PHO_DECIMALS - _module.stablecoinDecimals());

        // Stablecoin and PHO balances before
        StablecoinBalance memory before;
        before.userStablecoinBalance = _module.stablecoin().balanceOf(address(user1));
        before.moduleStablecoinBalance = _module.stablecoin().balanceOf(address(_module));
        before.userPHOBalance = pho.balanceOf(user1);
        before.userIssuedAmount = _module.issuedAmount(user1);
        before.totalPHOSupply = pho.totalSupply();

        // Deposit
        vm.warp(block.timestamp + moduleDelay + 1);
        vm.expectEmit(true, true, true, true);
        emit StablecoinDeposited(user1, _depositAmount);
        vm.prank(user1);
        _module.depositStablecoin(_depositAmount);

        // Stablecoin and PHO balances after
        StablecoinBalance memory aft; // note that after is a reserved keyword
        aft.userStablecoinBalance = _module.stablecoin().balanceOf(address(user1));
        aft.moduleStablecoinBalance = _module.stablecoin().balanceOf(address(_module));
        aft.userPHOBalance = pho.balanceOf(user1);
        aft.userIssuedAmount = _module.issuedAmount(user1);
        aft.totalPHOSupply = pho.totalSupply();

        // User balance - PHO up and stablecoin down
        assertEq(aft.userStablecoinBalance + _depositAmount, before.userStablecoinBalance);
        assertEq(aft.userPHOBalance, before.userPHOBalance + expectedIssuedAmount);

        // Deposit module balance - stablecoin up
        assertEq(aft.moduleStablecoinBalance, before.moduleStablecoinBalance + _depositAmount);

        // Check issued amount goes up
        assertEq(aft.userIssuedAmount, before.userIssuedAmount + expectedIssuedAmount);

        // Check PHO total supply goes up
        assertEq(aft.totalPHOSupply, before.totalPHOSupply + expectedIssuedAmount);
    }

    // Cannot redeem more than issued
    function testCannotRedeemStablecoinMoreThanIssued() public {
        uint256 depositAmount = ONE_HUNDRED_D6;
        uint256 redeemAmount = depositAmount * 10 ** 12;
        vm.prank(user1);
        usdcStablecoinDepositModule.depositStablecoin(depositAmount);
        vm.expectRevert(abi.encodeWithSelector(CannotRedeemMoreThanDeposited.selector));
        vm.prank(user1);
        usdcStablecoinDepositModule.redeemStablecoin(2 * redeemAmount);
    }

    // Test basic redeem with USDC
    function testRedeemStablecoinUSDC() public {
        uint256 depositAmount = ONE_HUNDRED_D6;
        uint256 redeemAmount = depositAmount * 10 ** 12;
        _testDepositAnyModule(depositAmount, usdcStablecoinDepositModule);
        _testRedeemAnyModule(redeemAmount, usdcStablecoinDepositModule);
    }

    // Test basic redeem with DAI
    function testRedeemStablecoinDAI() public {
        uint256 depositAmount = ONE_HUNDRED_D18;
        uint256 redeemAmount = ONE_HUNDRED_D18;
        _testDepositAnyModule(depositAmount, daiStablecoinDepositModule);
        _testRedeemAnyModule(redeemAmount, daiStablecoinDepositModule);
    }

    // Test basic redeem for any module
    function _testRedeemAnyModule(uint256 _redeemAmount, StablecoinDepositModule _module) public {
        // Divide by the decimal difference
        uint256 expectedStablecoinReturn =
            _redeemAmount / 10 ** (PHO_DECIMALS - _module.stablecoinDecimals());

        // Stablecoin and PHO balances before
        StablecoinBalance memory before;
        before.userStablecoinBalance = _module.stablecoin().balanceOf(address(user1));
        before.moduleStablecoinBalance = _module.stablecoin().balanceOf(address(_module));
        before.userPHOBalance = pho.balanceOf(user1);
        before.userIssuedAmount = _module.issuedAmount(user1);
        before.totalPHOSupply = pho.totalSupply();

        vm.expectEmit(true, true, true, true);
        emit PHORedeemed(user1, _redeemAmount);
        vm.prank(user1);
        _module.redeemStablecoin(_redeemAmount);

        // Stablecoin and PHO balances after
        StablecoinBalance memory aft; // note that after is a reserved keyword
        aft.userStablecoinBalance = _module.stablecoin().balanceOf(address(user1));
        aft.moduleStablecoinBalance = _module.stablecoin().balanceOf(address(_module));
        aft.userPHOBalance = pho.balanceOf(user1);
        aft.userIssuedAmount = _module.issuedAmount(user1);
        aft.totalPHOSupply = pho.totalSupply();

        // User balance - Stablecoin up and PHO down
        assertEq(aft.userStablecoinBalance, before.userStablecoinBalance + expectedStablecoinReturn);
        assertEq(aft.userPHOBalance, before.userPHOBalance - _redeemAmount);

        // Deposit module balance - Stablecoin down
        assertEq(
            aft.moduleStablecoinBalance, before.moduleStablecoinBalance - expectedStablecoinReturn
        );

        // Check issued amount before and after
        assertEq(aft.userIssuedAmount + _redeemAmount, before.userIssuedAmount);

        // Check PHO total supply before and after
        assertEq(aft.totalPHOSupply, before.totalPHOSupply - _redeemAmount);
    }
}
