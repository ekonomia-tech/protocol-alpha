// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../BaseSetup.t.sol";
import "src/protocol/contracts/TON.sol";
import "src/modules/zeroCouponBondModule/ZeroCouponBondModule.sol";

contract ZeroCouponBondModuleTest is BaseSetup {
    /// Errors
    error ZeroAddressDetected();
    error TimestampMustBeInFuture();
    error DepositTokenTooManyDecimals();
    error CannotDepositAfterWindowEnd();
    error MaturityNotReached();
    error CannotRedeemMoreThanIssued();

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
    uint256 public USDC_DEPOSIT_WINDOW_END;
    uint256 public DAI_DEPOSIT_WINDOW_END;
    uint256 public PHO_DEPOSIT_WINDOW_END;
    uint256 public USDC_MATURITY;
    uint256 public DAI_MATURITY;
    uint256 public PHO_MATURITY;

    function setUp() public {
        USDC_DEPOSIT_WINDOW_END = block.timestamp + 20;
        DAI_DEPOSIT_WINDOW_END = block.timestamp + 20;
        PHO_DEPOSIT_WINDOW_END = block.timestamp + 20;
        USDC_MATURITY = block.timestamp + 1000;
        DAI_MATURITY = block.timestamp + 1000;
        PHO_MATURITY = block.timestamp + 1000;

        usdcZeroCouponBondModule = new ZeroCouponBondModule(
            address(moduleManager),
            address(kernel),
            address(pho),
            address(usdc),
            USDC_BOND_TOKEN_NAME,
            USDC_BOND_TOKEN_SYMBOL,
            USDC_INTEREST_RATE,
            USDC_DEPOSIT_WINDOW_END,
            USDC_MATURITY
        );

        daiZeroCouponBondModule = new ZeroCouponBondModule(
            address(moduleManager),
            address(kernel),
            address(pho),
            address(dai),
            DAI_BOND_TOKEN_NAME,
            DAI_BOND_TOKEN_SYMBOL,
            DAI_INTEREST_RATE,
            DAI_DEPOSIT_WINDOW_END,
            DAI_MATURITY
        );

        phoZeroCouponBondModule = new ZeroCouponBondModule(
            address(moduleManager),
            address(kernel),
            address(pho),
            address(pho),
            PHO_BOND_TOKEN_NAME,
            PHO_BOND_TOKEN_SYMBOL,
            PHO_INTEREST_RATE,
            PHO_DEPOSIT_WINDOW_END,
            PHO_MATURITY
        );

        assertEq(usdcZeroCouponBondModule.totalSupply(), 0);
        assertEq(daiZeroCouponBondModule.totalSupply(), 0);
        assertEq(phoZeroCouponBondModule.totalSupply(), 0);

        // Add module to ModuleManager
        vm.prank(PHOGovernance);
        moduleManager.addModule(address(usdcZeroCouponBondModule));
        vm.prank(PHOGovernance);
        moduleManager.addModule(address(daiZeroCouponBondModule));
        vm.prank(PHOGovernance);
        moduleManager.addModule(address(phoZeroCouponBondModule));

        // Increase PHO ceilings for modules
        vm.prank(TONGovernance);
        moduleManager.setPHOCeilingForModule(address(usdcZeroCouponBondModule), ONE_MILLION_D18);
        vm.prank(TONGovernance);
        moduleManager.setPHOCeilingForModule(address(daiZeroCouponBondModule), ONE_MILLION_D18);
        vm.prank(TONGovernance);
        moduleManager.setPHOCeilingForModule(address(phoZeroCouponBondModule), ONE_MILLION_D18);

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
        vm.prank(user1);
        usdc.approve(address(usdcZeroCouponBondModule), TEN_THOUSAND_D6);
        // Approve sending DAI to DAI ZCB contract
        vm.prank(user1);
        dai.approve(address(daiZeroCouponBondModule), TEN_THOUSAND_D18);
        // Approve sending PHO to PHO ZCB contract
        vm.prank(user1);
        pho.approve(address(phoZeroCouponBondModule), ONE_HUNDRED_D18);
    }

    // Cannot set dispatcher to address(0)
    function testCannotMakeZCBWithModuleManagerZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        vm.prank(user1);
        usdcZeroCouponBondModule = new ZeroCouponBondModule(
            address(0),
            address(kernel),
            address(pho),
            address(usdc),
            USDC_BOND_TOKEN_NAME,
            USDC_BOND_TOKEN_SYMBOL,
            USDC_INTEREST_RATE,
            USDC_DEPOSIT_WINDOW_END,
            USDC_MATURITY
        );
    }

    // Cannot set kernel to address(0)
    function testCannotMakeZCBWithTellerZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        vm.prank(user1);
        usdcZeroCouponBondModule = new ZeroCouponBondModule(
            address(owner),
            address(0),
            address(pho),
            address(usdc),
            USDC_BOND_TOKEN_NAME,
            USDC_BOND_TOKEN_SYMBOL,
            USDC_INTEREST_RATE,
            USDC_DEPOSIT_WINDOW_END,
            USDC_MATURITY
        );
    }

    // Cannot set pho to address(0)
    function testCannotMakeZCBWithPHOZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        vm.prank(user1);
        usdcZeroCouponBondModule = new ZeroCouponBondModule(
            address(owner),
            address(kernel),
            address(0),
            address(usdc),
            USDC_BOND_TOKEN_NAME,
            USDC_BOND_TOKEN_SYMBOL,
            USDC_INTEREST_RATE,
            USDC_DEPOSIT_WINDOW_END,
            USDC_MATURITY
        );
    }

    // Cannot set pho to address(0)
    function testCannotMakeZCBWithDepositTokenZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        vm.prank(user1);
        usdcZeroCouponBondModule = new ZeroCouponBondModule(
            address(owner),
            address(kernel),
            address(pho),
            address(0),
            USDC_BOND_TOKEN_NAME,
            USDC_BOND_TOKEN_SYMBOL,
            USDC_INTEREST_RATE,
            USDC_DEPOSIT_WINDOW_END,
            USDC_MATURITY
        );
    }

    // Cannot set depositWindowEnd <= block.timestamp
    function testCannotMakeZCBWithDepositWindowEndLow() public {
        vm.expectRevert(abi.encodeWithSelector(TimestampMustBeInFuture.selector));
        vm.prank(user1);
        usdcZeroCouponBondModule = new ZeroCouponBondModule(
            address(owner),
            address(kernel),
            address(pho),
            address(usdc),
            USDC_BOND_TOKEN_NAME,
            USDC_BOND_TOKEN_SYMBOL,
            USDC_INTEREST_RATE,
            block.timestamp,
            USDC_MATURITY
        );
    }

    // Cannot set maturityTimestamp <= block.timestamp
    function testCannotMakeZCBWithMaturityTimestampLow() public {
        vm.expectRevert(abi.encodeWithSelector(TimestampMustBeInFuture.selector));
        vm.prank(user1);
        usdcZeroCouponBondModule = new ZeroCouponBondModule(
            address(owner),
            address(kernel),
            address(pho),
            address(usdc),
            USDC_BOND_TOKEN_NAME,
            USDC_BOND_TOKEN_SYMBOL,
            USDC_INTEREST_RATE,
            USDC_DEPOSIT_WINDOW_END,
            block.timestamp
        );
    }

    // Cannot set interest rate if not dispatcher
    function testCannotSetInterestRateOnlyModuleManager() public {
        vm.expectRevert("Only moduleManager");
        vm.prank(user1);
        usdcZeroCouponBondModule.setInterestRate(3e5);
    }

    // Cannot deposit after window end
    function testCannotDepositAfterWindowEnd() public {
        uint256 depositAmount = ONE_HUNDRED_D6;
        // deposit
        vm.warp(USDC_DEPOSIT_WINDOW_END + 1);
        vm.expectRevert(abi.encodeWithSelector(CannotDepositAfterWindowEnd.selector));
        vm.prank(user1);
        usdcZeroCouponBondModule.depositBond(depositAmount);
    }

    // Basic deposit for non-18 decimals
    function testDepositBondUSDC() public {
        uint256 depositAmount = ONE_HUNDRED_D6;
        uint256 expectedMint = ((depositAmount * (1e6 + USDC_INTEREST_RATE)) / 1e6) * 10 ** 12;
        // deposit
        vm.expectEmit(true, false, false, true);
        emit BondIssued(user1, depositAmount, expectedMint);
        vm.prank(user1);
        usdcZeroCouponBondModule.depositBond(depositAmount);
        // check expected mint amount
        assertEq(usdcZeroCouponBondModule.totalSupply(), expectedMint);
        assertEq(usdcZeroCouponBondModule.issuedAmount(user1), expectedMint);
    }

    // Basic deposit for standard 18 decimals
    function testDepositBondDAI() public {
        uint256 depositAmount = ONE_HUNDRED_D18;
        // deposit
        vm.prank(user1);
        daiZeroCouponBondModule.depositBond(depositAmount);
        // check expected mint amount
        uint256 expectedMint = ((depositAmount * (1e6 + DAI_INTEREST_RATE)) / 1e6);
        assertEq(daiZeroCouponBondModule.totalSupply(), expectedMint);
        assertEq(daiZeroCouponBondModule.issuedAmount(user1), expectedMint);
    }

    // Cannot redeem bond before maturtity
    function testCannotRedeemBondBeforeMaturity() public {
        uint256 depositAmount = ONE_HUNDRED_D6;
        uint256 redeemAmount = ((depositAmount * (1e6 + USDC_INTEREST_RATE)) / 1e6) * 10 ** 12;
        vm.prank(user1);
        usdcZeroCouponBondModule.depositBond(depositAmount);
        vm.expectRevert(abi.encodeWithSelector(MaturityNotReached.selector));
        vm.prank(user1);
        usdcZeroCouponBondModule.redeemBond(redeemAmount);
    }

    // Cannot redeem more than issued
    function testCannotRedeemBondMoreThanIssued() public {
        uint256 depositAmount = ONE_HUNDRED_D6;
        uint256 redeemAmount = ((depositAmount * (1e6 + USDC_INTEREST_RATE)) / 1e6) * 10 ** 12;
        vm.warp(USDC_DEPOSIT_WINDOW_END);
        vm.prank(user1);
        usdcZeroCouponBondModule.depositBond(depositAmount / 2);
        vm.warp(USDC_MATURITY);
        vm.expectRevert(abi.encodeWithSelector(CannotRedeemMoreThanIssued.selector));
        vm.prank(user1);
        usdcZeroCouponBondModule.redeemBond(redeemAmount);
    }

    // Test basic redeem with non 18 decimals
    function testRedeemBondUSDC() public {
        uint256 depositAmount = ONE_HUNDRED_D6;
        uint256 redeemAmount = ((depositAmount * (1e6 + USDC_INTEREST_RATE)) / 1e6) * 10 ** 12;
        vm.warp(USDC_DEPOSIT_WINDOW_END);

        uint256 phoBalanceUserBefore = pho.balanceOf(user1);
        uint256 phoZCBBalanceBefore = pho.balanceOf(address(usdcZeroCouponBondModule));

        vm.prank(user1);
        usdcZeroCouponBondModule.depositBond(depositAmount);

        vm.warp(USDC_MATURITY);

        vm.prank(user1);
        usdcZeroCouponBondModule.redeemBond(redeemAmount);

        uint256 phoBalanceUserAfter = pho.balanceOf(user1);
        uint256 phoZCBBalanceAfter = pho.balanceOf(address(usdcZeroCouponBondModule));

        assertEq(phoBalanceUserAfter, phoBalanceUserBefore + redeemAmount);

        assertEq(usdcZeroCouponBondModule.issuedAmount(user1), 0);
    }

    // Test basic redeem with standard 18 decimals
    function testRedeemBondDAI() public {
        uint256 depositAmount = ONE_HUNDRED_D18;
        uint256 redeemAmount = ((depositAmount * (1e6 + DAI_INTEREST_RATE)) / 1e6);
        vm.warp(DAI_DEPOSIT_WINDOW_END);

        uint256 phoBalanceUserBefore = pho.balanceOf(user1);
        uint256 phoZCBBalanceBefore = pho.balanceOf(address(daiZeroCouponBondModule));

        vm.prank(user1);
        daiZeroCouponBondModule.depositBond(depositAmount);

        vm.warp(DAI_MATURITY);

        vm.prank(user1);
        daiZeroCouponBondModule.redeemBond(redeemAmount);

        vm.warp(DAI_MATURITY);

        uint256 phoBalanceUserAfter = pho.balanceOf(user1);
        uint256 phoZCBBalanceAfter = pho.balanceOf(address(daiZeroCouponBondModule));

        assertEq(phoBalanceUserAfter, phoBalanceUserBefore + redeemAmount);

        assertEq(daiZeroCouponBondModule.issuedAmount(user1), 0);
    }

    // Test basic redeem with with PHO
    function testRedeemBondPHO() public {
        uint256 depositAmount = ONE_HUNDRED_D18;
        uint256 redeemAmount = ((depositAmount * (1e6 + PHO_INTEREST_RATE)) / 1e6);

        vm.warp(PHO_DEPOSIT_WINDOW_END);

        uint256 phoBalanceUserBefore = pho.balanceOf(user1);
        uint256 phoZCBBalanceBefore = pho.balanceOf(address(phoZeroCouponBondModule));

        vm.prank(user1);
        phoZeroCouponBondModule.depositBond(depositAmount);

        uint256 phoBalanceUserAfterDeposit = pho.balanceOf(user1);
        uint256 phoZCBBalanceAfterDeposit = pho.balanceOf(address(phoZeroCouponBondModule));

        assertEq(phoBalanceUserAfterDeposit, phoBalanceUserBefore - depositAmount);
        assertEq(phoZCBBalanceAfterDeposit, phoZCBBalanceBefore + depositAmount);

        vm.warp(PHO_MATURITY);

        vm.prank(user1);
        phoZeroCouponBondModule.redeemBond(redeemAmount);

        uint256 phoBalanceUserAfterRedeem = pho.balanceOf(user1);
        uint256 phoZCBBalanceAfterRedeem = pho.balanceOf(address(phoZeroCouponBondModule));

        assertEq(phoBalanceUserAfterRedeem, phoBalanceUserAfterDeposit + redeemAmount);

        assertEq(phoZeroCouponBondModule.issuedAmount(user1), 0);
    }
}
