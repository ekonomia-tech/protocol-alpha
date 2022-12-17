// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "../../BaseSetup.t.sol";
import "@protocol/contracts/TON.sol";
import "@modules/zeroCouponBondModule/ZeroCouponBondModule.sol";

contract ZeroCouponBondModuleTest is BaseSetup {
    /// Errors
    error ZeroAddressDetected();
    error DepositWindowInvalid();
    error OverEighteenDecimals();
    error CannotDepositBeforeWindowOpen();
    error CannotDepositAfterWindowEnd();
    error CannotRedeemBeforeWindowEnd();
    error CannotRedeemMoreThanIssued();
    error OnlyModuleManager();

    /// Events
    event BondIssued(address indexed depositor, uint256 depositAmount, uint256 mintAmount);
    event BondRedeemed(address indexed redeemer, uint256 redeemAmount);
    event InterestRateSet(uint256 interestRate);

    ZeroCouponBondModule public usdcZeroCouponBondModule;
    ZeroCouponBondModule public daiZeroCouponBondModule;
    ZeroCouponBondModule public phoZeroCouponBondModule;

    string public USDC_BOND_TOKEN_NAME = "USDC-1Year";
    string public USDC_BOND_TOKEN_SYMBOL = "USDC-1Y";
    string public DAI_BOND_TOKEN_NAME = "DAI-1Year";
    string public DAI_BOND_TOKEN_SYMBOL = "DAI-1Y";
    string public PHO_BOND_TOKEN_NAME = "PHO-1Year";
    string public PHO_BOND_TOKEN_SYMBOL = "PHO-1Y";
    uint256 public constant USDC_INTEREST_RATE = 5e5; // 5%
    uint256 public constant DAI_INTEREST_RATE = 4e5; // 4%
    uint256 public constant PHO_INTEREST_RATE = 3e5; // 3%
    uint256 public USDC_DEPOSIT_WINDOW_OPEN;
    uint256 public DAI_DEPOSIT_WINDOW_OPEN;
    uint256 public PHO_DEPOSIT_WINDOW_OPEN;
    uint256 public USDC_DEPOSIT_WINDOW_END;
    uint256 public DAI_DEPOSIT_WINDOW_END;
    uint256 public PHO_DEPOSIT_WINDOW_END;

    uint256 public constant USDC_SCALE = 10 ** 12;

    // Track balance for deposit tokens & PHO
    struct DepositTokenBalance {
        uint256 userDepositTokenBalance;
        uint256 moduleDepositTokenBalance;
        uint256 userPHOBalance;
        uint256 modulePHOBalance;
        uint256 userIssuedAmount;
        uint256 totalPHOSupply;
    }

    function setUp() public {
        // Starts at t + 100 until t + 1100;
        USDC_DEPOSIT_WINDOW_OPEN = block.timestamp + 100;
        DAI_DEPOSIT_WINDOW_OPEN = block.timestamp + 100;
        PHO_DEPOSIT_WINDOW_OPEN = block.timestamp + 100;
        USDC_DEPOSIT_WINDOW_END = block.timestamp + 1100;
        DAI_DEPOSIT_WINDOW_END = block.timestamp + 1100;
        PHO_DEPOSIT_WINDOW_END = block.timestamp + 1100;

        usdcZeroCouponBondModule = new ZeroCouponBondModule(
            address(moduleManager),
            address(kernel),
            address(pho),
            address(usdc),
            USDC_BOND_TOKEN_NAME,
            USDC_BOND_TOKEN_SYMBOL,
            USDC_INTEREST_RATE,
            USDC_DEPOSIT_WINDOW_OPEN,
            USDC_DEPOSIT_WINDOW_END
        );

        daiZeroCouponBondModule = new ZeroCouponBondModule(
            address(moduleManager),
            address(kernel),
            address(pho),
            address(dai),
            DAI_BOND_TOKEN_NAME,
            DAI_BOND_TOKEN_SYMBOL,
            DAI_INTEREST_RATE,
            DAI_DEPOSIT_WINDOW_OPEN,
            DAI_DEPOSIT_WINDOW_END
        );

        phoZeroCouponBondModule = new ZeroCouponBondModule(
            address(moduleManager),
            address(kernel),
            address(pho),
            address(pho),
            PHO_BOND_TOKEN_NAME,
            PHO_BOND_TOKEN_SYMBOL,
            PHO_INTEREST_RATE,
            PHO_DEPOSIT_WINDOW_OPEN,
            PHO_DEPOSIT_WINDOW_END
        );

        assertEq(usdcZeroCouponBondModule.totalSupply(), 0);
        assertEq(daiZeroCouponBondModule.totalSupply(), 0);
        assertEq(phoZeroCouponBondModule.totalSupply(), 0);

        // Add module to ModuleManager
        vm.startPrank(address(PHOTimelock));
        moduleManager.addModule(address(usdcZeroCouponBondModule));
        moduleManager.addModule(address(daiZeroCouponBondModule));
        moduleManager.addModule(address(phoZeroCouponBondModule));
        vm.stopPrank();

        // Increase PHO ceilings for modules
        vm.startPrank(address(TONTimelock));
        moduleManager.setPHOCeilingForModule(address(usdcZeroCouponBondModule), ONE_MILLION_D18);
        moduleManager.setPHOCeilingForModule(address(daiZeroCouponBondModule), ONE_MILLION_D18);
        moduleManager.setPHOCeilingForModule(address(phoZeroCouponBondModule), ONE_MILLION_D18);
        vm.stopPrank();

        vm.warp(block.timestamp + moduleManager.moduleDelay());
        moduleManager.executeCeilingUpdate(address(usdcZeroCouponBondModule));
        moduleManager.executeCeilingUpdate(address(daiZeroCouponBondModule));
        moduleManager.executeCeilingUpdate(address(phoZeroCouponBondModule));
        // Fund user with USDC
        vm.prank(richGuy);
        usdc.transfer(user1, TEN_THOUSAND_D6);
        // Fund user with DAI
        vm.prank(daiWhale);
        dai.transfer(user1, TEN_THOUSAND_D18);
        // Mint PHO to user
        vm.prank(address(moduleManager));
        kernel.mintPHO(address(user1), ONE_HUNDRED_D18);

        // Approve sending USDC to USDC ZCB contract
        vm.startPrank(user1);
        usdc.approve(address(usdcZeroCouponBondModule), TEN_THOUSAND_D6);
        // Approve sending DAI to DAI ZCB contract
        dai.approve(address(daiZeroCouponBondModule), TEN_THOUSAND_D18);
        // Approve sending PHO to PHO ZCB contract
        pho.approve(address(phoZeroCouponBondModule), ONE_HUNDRED_D18);
        vm.stopPrank();
    }

    // Cannot set addresses to 0
    function testCannotMakeZCBModuleWithZeroAddress() public {
        vm.startPrank(user1);
        // ModuleManager
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        usdcZeroCouponBondModule = new ZeroCouponBondModule(
            address(0),
            address(kernel),
            address(pho),
            address(usdc),
            USDC_BOND_TOKEN_NAME,
            USDC_BOND_TOKEN_SYMBOL,
            USDC_INTEREST_RATE,
            USDC_DEPOSIT_WINDOW_OPEN,
            USDC_DEPOSIT_WINDOW_END
        );

        // Kernel
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        usdcZeroCouponBondModule = new ZeroCouponBondModule(
            address(moduleManager),
            address(0),
            address(pho),
            address(usdc),
            USDC_BOND_TOKEN_NAME,
            USDC_BOND_TOKEN_SYMBOL,
            USDC_INTEREST_RATE,
            USDC_DEPOSIT_WINDOW_OPEN,
            USDC_DEPOSIT_WINDOW_END
        );

        // PHO
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        usdcZeroCouponBondModule = new ZeroCouponBondModule(
            address(moduleManager),
            address(kernel),
            address(0),
            address(usdc),
            USDC_BOND_TOKEN_NAME,
            USDC_BOND_TOKEN_SYMBOL,
            USDC_INTEREST_RATE,
            USDC_DEPOSIT_WINDOW_OPEN,
            USDC_DEPOSIT_WINDOW_END
        );

        // Deposit Token
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        usdcZeroCouponBondModule = new ZeroCouponBondModule(
            address(moduleManager),
            address(kernel),
            address(pho),
            address(0),
            USDC_BOND_TOKEN_NAME,
            USDC_BOND_TOKEN_SYMBOL,
            USDC_INTEREST_RATE,
            USDC_DEPOSIT_WINDOW_OPEN,
            USDC_DEPOSIT_WINDOW_END
        );

        vm.stopPrank();
    }

    /// Invalid deposit window

    // Cannot set depositWindowOpen <= block.timestamp
    function testCannotMakeZCBWithDepositWindowOpenLow() public {
        vm.expectRevert(abi.encodeWithSelector(DepositWindowInvalid.selector));
        vm.prank(user1);
        usdcZeroCouponBondModule = new ZeroCouponBondModule(
            address(moduleManager),
            address(kernel),
            address(pho),
            address(usdc),
            USDC_BOND_TOKEN_NAME,
            USDC_BOND_TOKEN_SYMBOL,
            USDC_INTEREST_RATE,
            block.timestamp,
            USDC_DEPOSIT_WINDOW_END
        );
    }

    // Cannot set depositWindowEnd <= block.timestamp
    function testCannotMakeZCBWithDepositWindowEndLow() public {
        vm.expectRevert(abi.encodeWithSelector(DepositWindowInvalid.selector));
        vm.prank(user1);
        usdcZeroCouponBondModule = new ZeroCouponBondModule(
            address(moduleManager),
            address(kernel),
            address(pho),
            address(usdc),
            USDC_BOND_TOKEN_NAME,
            USDC_BOND_TOKEN_SYMBOL,
            USDC_INTEREST_RATE,
            USDC_DEPOSIT_WINDOW_OPEN,
            block.timestamp
        );
    }

    // Cannot set depositWindowOpen >= depositWindowEnd
    function testCannotMakeZCBWithDepositWindowOpenPastEnd() public {
        vm.expectRevert(abi.encodeWithSelector(DepositWindowInvalid.selector));
        vm.prank(user1);
        usdcZeroCouponBondModule = new ZeroCouponBondModule(
            address(moduleManager),
            address(kernel),
            address(pho),
            address(usdc),
            USDC_BOND_TOKEN_NAME,
            USDC_BOND_TOKEN_SYMBOL,
            USDC_INTEREST_RATE,
            USDC_DEPOSIT_WINDOW_END,
            USDC_DEPOSIT_WINDOW_OPEN
        );
    }

    // Cannot set interest rate if not ModuleManager
    function testCannotSetInterestRateOnlyModuleManager() public {
        vm.expectRevert(abi.encodeWithSelector(OnlyModuleManager.selector));
        vm.prank(user1);
        usdcZeroCouponBondModule.setInterestRate(3e5);
    }

    // Set interest rate successfully
    function testBasicSetInterestRate() public {
        vm.expectEmit(true, true, true, true);
        emit InterestRateSet(3e5);
        vm.prank(address(moduleManager));
        usdcZeroCouponBondModule.setInterestRate(3e5);
    }

    // Cannot deposit before window open
    function testCannotDepositBeforeWindowOpen() public {
        uint256 depositAmount = ONE_HUNDRED_D6;
        // Deposit
        vm.warp(USDC_DEPOSIT_WINDOW_OPEN - 1);
        vm.expectRevert(abi.encodeWithSelector(CannotDepositBeforeWindowOpen.selector));
        vm.prank(user1);
        usdcZeroCouponBondModule.depositBond(depositAmount);
    }

    // Cannot deposit after window end
    function testCannotDepositAfterWindowEnd() public {
        uint256 depositAmount = ONE_HUNDRED_D6;
        // Deposit
        vm.warp(USDC_DEPOSIT_WINDOW_END + 1);
        vm.expectRevert(abi.encodeWithSelector(CannotDepositAfterWindowEnd.selector));
        vm.prank(user1);
        usdcZeroCouponBondModule.depositBond(depositAmount);
    }

    // Basic deposit for non-18 decimals - full interest rate
    function testDepositBondUSDCInterestRateFull() public {
        uint256 depositAmount = ONE_HUNDRED_D6;
        uint256 expectedMint = ((depositAmount * (1e6 + USDC_INTEREST_RATE)) / 1e6) * USDC_SCALE;

        _testDepositAnyModule(
            depositAmount, expectedMint, usdcZeroCouponBondModule, USDC_DEPOSIT_WINDOW_OPEN
        );
    }

    // Basic deposit for standard 18 decimals - full interest rate
    function testDepositBondDAIInterestRateFull() public {
        uint256 depositAmount = ONE_HUNDRED_D18;
        uint256 expectedMint = ((depositAmount * (1e6 + DAI_INTEREST_RATE)) / 1e6);

        _testDepositAnyModule(
            depositAmount, expectedMint, daiZeroCouponBondModule, DAI_DEPOSIT_WINDOW_OPEN
        );
    }

    // Basic deposit for non-18 decimals - half interest rate
    function testDepositBondUSDCInterestRateHalf() public {
        uint256 depositAmount = ONE_HUNDRED_D6;
        uint256 expectedMint = ((depositAmount * (1e6 + USDC_INTEREST_RATE / 2)) / 1e6) * USDC_SCALE;

        uint256 duration = USDC_DEPOSIT_WINDOW_END - USDC_DEPOSIT_WINDOW_OPEN;
        uint256 halfway = (USDC_DEPOSIT_WINDOW_END - duration / 2);

        _testDepositAnyModule(depositAmount, expectedMint, usdcZeroCouponBondModule, halfway);
    }

    // Basic deposit for standard 18 decimals - half interest rate
    function testDepositBondDAIInterestRateHalf() public {
        uint256 depositAmount = ONE_HUNDRED_D18;
        uint256 expectedMint = ((depositAmount * (1e6 + DAI_INTEREST_RATE / 2)) / 1e6);
        uint256 duration = DAI_DEPOSIT_WINDOW_END - DAI_DEPOSIT_WINDOW_OPEN;
        uint256 halfway = (DAI_DEPOSIT_WINDOW_END - duration / 2);

        _testDepositAnyModule(depositAmount, expectedMint, daiZeroCouponBondModule, halfway);
    }

    // Helper function to test deposit from any ZCB module
    function _testDepositAnyModule(
        uint256 _depositAmount,
        uint256 _expectedMintAmount,
        ZeroCouponBondModule _module,
        uint256 _depositTimestamp
    ) public {
        // depositToken and PHO balances before
        DepositTokenBalance memory before;
        before.userDepositTokenBalance = _module.depositToken().balanceOf(address(user1));
        before.moduleDepositTokenBalance = _module.depositToken().balanceOf(address(_module));
        before.userPHOBalance = pho.balanceOf(user1);
        before.modulePHOBalance = pho.balanceOf(address(_module));
        before.userIssuedAmount = _module.issuedAmount(user1);
        before.totalPHOSupply = pho.totalSupply();

        // Deposit
        vm.warp(_depositTimestamp);
        vm.expectEmit(true, true, true, true);
        emit BondIssued(user1, _depositAmount, _expectedMintAmount);
        vm.prank(user1);
        _module.depositBond(_depositAmount);

        // depositToken and PHO balances after
        DepositTokenBalance memory aft; // note that after is a reserved keyword
        aft.userDepositTokenBalance = _module.depositToken().balanceOf(address(user1));
        aft.moduleDepositTokenBalance = _module.depositToken().balanceOf(address(_module));
        aft.modulePHOBalance = pho.balanceOf(address(_module));
        aft.userPHOBalance = pho.balanceOf(user1);
        aft.userIssuedAmount = _module.issuedAmount(user1);
        aft.totalPHOSupply = pho.totalSupply();

        // User balance - PHO same and depositToken down
        assertEq(aft.userPHOBalance, before.userPHOBalance);
        assertEq(aft.userDepositTokenBalance + _depositAmount, before.userDepositTokenBalance);

        // ZCB module balance - PHO same, depositToken up
        assertEq(aft.modulePHOBalance, before.modulePHOBalance);
        assertEq(aft.moduleDepositTokenBalance, before.moduleDepositTokenBalance + _depositAmount);

        // Check issued amount goes up
        assertEq(aft.userIssuedAmount, before.userIssuedAmount + _expectedMintAmount);

        // Check PHO supply stays same
        assertEq(aft.totalPHOSupply, before.totalPHOSupply);
    }

    // Cannot redeem bond before window end
    function testCannotRedeemBondBeforeWindowEnd() public {
        uint256 depositAmount = ONE_HUNDRED_D6;
        vm.warp(USDC_DEPOSIT_WINDOW_OPEN);
        vm.prank(user1);
        usdcZeroCouponBondModule.depositBond(depositAmount);
        vm.expectRevert(abi.encodeWithSelector(CannotRedeemBeforeWindowEnd.selector));
        vm.prank(user1);
        usdcZeroCouponBondModule.redeemBond();
    }

    // Test basic redeem (full interest rate) with non 18 decimals
    function testRedeemBondUSDCInterestRateFull() public {
        uint256 depositAmount = ONE_HUNDRED_D6;
        uint256 expectedMint = ((depositAmount * (1e6 + USDC_INTEREST_RATE)) / 1e6) * USDC_SCALE;

        _testDepositAnyModule(
            depositAmount, expectedMint, usdcZeroCouponBondModule, USDC_DEPOSIT_WINDOW_OPEN
        );

        uint256 redeemAmount = ((depositAmount * (1e6 + USDC_INTEREST_RATE)) / 1e6) * USDC_SCALE;
        uint256 redeemTimestamp = USDC_DEPOSIT_WINDOW_END;

        _testRedeemAnyModule(redeemAmount, usdcZeroCouponBondModule, redeemTimestamp);
    }

    // Test basic redeem (full interest rate) with non 18 decimals
    function testRedeemBondUSDCInterestRateHalf() public {
        uint256 depositAmount = ONE_HUNDRED_D6;

        uint256 expectedMint = ((depositAmount * (1e6 + USDC_INTEREST_RATE / 2)) / 1e6) * USDC_SCALE;

        // Deposit at T/2 (midway)
        uint256 depositTimestamp =
            USDC_DEPOSIT_WINDOW_END - (USDC_DEPOSIT_WINDOW_END - USDC_DEPOSIT_WINDOW_OPEN) / 2;

        _testDepositAnyModule(
            depositAmount, expectedMint, usdcZeroCouponBondModule, depositTimestamp
        );

        uint256 redeemAmount = ((depositAmount * (1e6 + USDC_INTEREST_RATE / 2)) / 1e6) * USDC_SCALE;
        uint256 redeemTimestamp = USDC_DEPOSIT_WINDOW_END;

        _testRedeemAnyModule(redeemAmount, usdcZeroCouponBondModule, redeemTimestamp);
    }

    // Test basic redeem (full interest rate) with non 18 decimals
    function testRedeemBondDAIInterestRateFull() public {
        uint256 depositAmount = ONE_HUNDRED_D18;
        uint256 expectedMint = ((depositAmount * (1e6 + DAI_INTEREST_RATE)) / 1e6);

        _testDepositAnyModule(
            depositAmount, expectedMint, daiZeroCouponBondModule, DAI_DEPOSIT_WINDOW_OPEN
        );

        uint256 redeemAmount = ((depositAmount * (1e6 + DAI_INTEREST_RATE)) / 1e6);
        uint256 redeemTimestamp = DAI_DEPOSIT_WINDOW_END;

        _testRedeemAnyModule(redeemAmount, daiZeroCouponBondModule, redeemTimestamp);
    }

    // Helper function to redeem deposit from any ZCB module
    function _testRedeemAnyModule(
        uint256 _redeemAmount,
        ZeroCouponBondModule _module,
        uint256 _redeemTimestamp
    ) public {
        // depositToken and PHO balances before
        DepositTokenBalance memory before;
        before.userDepositTokenBalance = _module.depositToken().balanceOf(address(user1));
        before.moduleDepositTokenBalance = _module.depositToken().balanceOf(address(_module));
        before.userPHOBalance = pho.balanceOf(user1);
        before.modulePHOBalance = pho.balanceOf(address(_module));
        before.userIssuedAmount = _module.issuedAmount(user1);
        before.totalPHOSupply = pho.totalSupply();

        // Redeem
        vm.warp(_redeemTimestamp);
        vm.expectEmit(true, true, true, true);
        emit BondRedeemed(user1, _redeemAmount);
        vm.prank(user1);
        _module.redeemBond();

        // depositToken and PHO balances after
        DepositTokenBalance memory aft; // note that after is a reserved keyword
        aft.userDepositTokenBalance = _module.depositToken().balanceOf(address(user1));
        aft.moduleDepositTokenBalance = _module.depositToken().balanceOf(address(_module));
        aft.modulePHOBalance = pho.balanceOf(address(_module));
        aft.userPHOBalance = pho.balanceOf(user1);
        aft.userIssuedAmount = _module.issuedAmount(user1);
        aft.totalPHOSupply = pho.totalSupply();

        // User balance - PHO up and depositToken same
        assertEq(aft.userPHOBalance, before.userPHOBalance + _redeemAmount);
        assertEq(aft.userDepositTokenBalance, before.userDepositTokenBalance);

        // ZCB module balance - PHO same, depositToken same
        assertEq(aft.modulePHOBalance, before.modulePHOBalance);
        assertEq(aft.moduleDepositTokenBalance, before.moduleDepositTokenBalance);

        // Check issued amount goes down
        assertEq(aft.userIssuedAmount, before.userIssuedAmount - _redeemAmount);

        // Check PHO supply increases
        assertEq(aft.totalPHOSupply, before.totalPHOSupply + _redeemAmount);
    }

    // Test basic redeem for PHO (full interest rate)
    // Note: Custom vs. _testRedeemAnyModule since PHO is depositToken
    function testRedeemBondPHOInterestRateFull() public {
        uint256 depositAmount = ONE_HUNDRED_D18;
        uint256 redeemAmount = ((depositAmount * (1e6 + PHO_INTEREST_RATE)) / 1e6);
        vm.warp(PHO_DEPOSIT_WINDOW_END);

        // PHO balances before
        uint256 phoZCBBalanceBefore = pho.balanceOf(address(phoZeroCouponBondModule));

        vm.prank(user1);
        phoZeroCouponBondModule.depositBond(depositAmount);

        uint256 issuedAmountUserBefore = phoZeroCouponBondModule.issuedAmount(user1);
        uint256 phoTotalSupplyBefore = pho.totalSupply();

        vm.warp(DAI_DEPOSIT_WINDOW_END);

        vm.prank(user1);
        phoZeroCouponBondModule.redeemBond();

        // PHO balances after
        uint256 phoBalanceUserAfter = pho.balanceOf(user1);
        uint256 phoZCBBalanceAfter = pho.balanceOf(address(phoZeroCouponBondModule));

        uint256 issuedAmountUserAfter = phoZeroCouponBondModule.issuedAmount(user1);
        uint256 phoTotalSupplyAfter = pho.totalSupply();

        // Check that PHO balances before and after are expected

        // User balance - PHO should be redeemAmount
        assertEq(phoBalanceUserAfter, redeemAmount);

        // ZCB module balance -  PHO increased
        assertEq(phoZCBBalanceAfter, phoZCBBalanceBefore + depositAmount);

        // Check issued amount before and after
        assertEq(issuedAmountUserBefore - issuedAmountUserAfter, redeemAmount);

        // Check PHO total supply before and after
        assertEq(phoTotalSupplyAfter, phoTotalSupplyBefore + redeemAmount);
    }
}
