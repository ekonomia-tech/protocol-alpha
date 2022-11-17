// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../../BaseSetup.t.sol";
import "@external/curve/ICurvePool.sol";
import "@external/curve/ICurveFactory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@modules/priceController/PriceController.sol";
import "@modules/fraxBPInitModule/FraxBPInitModule.sol";

contract FraxBPInitModuleTest is BaseSetup {
    /// Errors
    error ZeroAddressDetected();
    error CannotRedeemMoreThanDeposited();
    error OverEighteenDecimals();
    error CannotDepositAfterSaleEnded();
    error MaxCapNotMet();
    error FraxBPPHOMetapoolNotSet();
    error MustHaveEqualAmounts();

    /// Events
    event BondIssued(
        address indexed depositor, uint256 usdcAmount, uint256 fraxAmount, uint256 mintAmount
    );
    event BondRedeemed(address indexed redeemer, uint256 redeemAmount);

    ICurvePool public fraxBPPHOMetapool;
    FraxBPInitModule public fraxBPInitModule;

    /// Constants
    string public FRAX_BP_BOND_TOKEN_NAME = "FraxBP-3mo";
    string public FRAX_BP_BOND_TOKEN_SYMBOL = "FRAXBP-3M";
    uint256 public constant USDC_SCALE = 10 ** 12;
    uint256 public constant maxCap = 20000000 * 10 ** 18;
    uint256 public saleEndDate;

    // Track balance for FRAX, USDC, FRAXBP LP, & PHO
    struct DepositTokenBalance {
        uint256 userUSDCBalance;
        uint256 moduleUSDCBalance;
        uint256 userFRAXBalance;
        uint256 moduleFRAXBalance;
        uint256 userFraxBPLPBalance;
        uint256 moduleFraxBPLPBalance;
        uint256 userPHOBalance;
        uint256 modulePHOBalance;
        uint256 userIssuedAmount;
        uint256 totalPHOSupply;
    }

    function setUp() public {
        fraxBPLP = IERC20(FRAXBP_LP_TOKEN);
        curveFactory = ICurveFactory(metaPoolFactoryAddress);

        // Give user FRAX and USDC
        _getFRAX(user1, TEN_THOUSAND_D18);
        _getUSDC(user1, TEN_THOUSAND_D6);

        fraxBPPHOMetapool = ICurvePool(_deployFraxBPPHOPoolCustom(20));

        //_deployFraxBPPHOPoolCustom
        saleEndDate = block.timestamp + 10000;

        vm.prank(owner);
        fraxBPInitModule = new FraxBPInitModule(
            address(moduleManager),
            address(kernel),
            FRAX_BP_BOND_TOKEN_NAME,
            FRAX_BP_BOND_TOKEN_SYMBOL,
            address(fraxBPPHOMetapool),
            address(pho),
            maxCap,
            saleEndDate
        );

        vm.prank(PHOGovernance);
        moduleManager.addModule(address(fraxBPInitModule));

        vm.prank(TONGovernance);
        moduleManager.setPHOCeilingForModule(address(fraxBPInitModule), ONE_MILLION_D18 * 10);

        vm.warp(block.timestamp + moduleManager.moduleDelay());
        moduleManager.executeCeilingUpdate(address(fraxBPInitModule));

        // TODO: edit?
        _fundAndApproveUSDC(
            address(fraxBPInitModule),
            address(fraxBPPHOMetapool),
            ONE_HUNDRED_THOUSAND_D6,
            ONE_HUNDRED_THOUSAND_D6
        );

        // Approve sending USDC to FraxBP Init Module
        vm.startPrank(user1);
        usdc.approve(address(fraxBPInitModule), TEN_THOUSAND_D6);
        // Approve sending DAI to DAI ZCB contract
        frax.approve(address(fraxBPInitModule), TEN_THOUSAND_D18);
        vm.stopPrank();
    }

    // Cannot set addresses to 0
    function testCannotMakeFraxBpModuleWithZeroAddress() public {
        vm.startPrank(user1);
        // ModuleManager
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        fraxBPInitModule = new FraxBPInitModule(
            address(0),
            address(kernel),
            FRAX_BP_BOND_TOKEN_NAME,
            FRAX_BP_BOND_TOKEN_SYMBOL,
            address(fraxBPPHOMetapool),
            address(pho),
            maxCap,
            block.timestamp + 1000
        );

        // Kernel
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        fraxBPInitModule = new FraxBPInitModule(
            address(moduleManager),
            address(0),
            FRAX_BP_BOND_TOKEN_NAME,
            FRAX_BP_BOND_TOKEN_SYMBOL,
            address(fraxBPPHOMetapool),
            address(pho),
            maxCap,
            block.timestamp + 1000
        );

        // Frax BP / PHO Pool
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        fraxBPInitModule = new FraxBPInitModule(
            address(moduleManager),
            address(kernel),
            FRAX_BP_BOND_TOKEN_NAME,
            FRAX_BP_BOND_TOKEN_SYMBOL,
            address(0),
            address(pho),
            maxCap,
            block.timestamp + 1000
        );

        // PHO
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        fraxBPInitModule = new FraxBPInitModule(
            address(moduleManager),
            address(kernel),
            FRAX_BP_BOND_TOKEN_NAME,
            FRAX_BP_BOND_TOKEN_SYMBOL,
            address(fraxBPPHOMetapool),
            address(0),
            maxCap,
            block.timestamp + 1000
        );

        vm.stopPrank();
    }

    // Basic deposit
    function testDepositFull() public {
        uint256 usdcDepositAmount = ONE_HUNDRED_D6;
        uint256 fraxDepositAmount = ONE_HUNDRED_D18;
        uint256 expectedMint = 2 * fraxDepositAmount;
        _testDepositAnyModule(
            usdcDepositAmount, fraxDepositAmount, expectedMint, fraxBPInitModule, saleEndDate - 500
        );
    }

    // Helper function to test deposit from any FraxBPInitModule
    function _testDepositAnyModule(
        uint256 _usdcDepositAmount,
        uint256 _fraxDepositAmount,
        uint256 _expectedMintAmount,
        FraxBPInitModule _module,
        uint256 _depositTimestamp
    ) public {
        uint256 usdcDepositAmount = _usdcDepositAmount;
        uint256 fraxDepositAmount = _fraxDepositAmount;
        // USDC, FRAX and PHO balances before
        DepositTokenBalance memory before;
        before.userUSDCBalance = usdc.balanceOf(address(user1));
        before.moduleUSDCBalance = usdc.balanceOf(address(_module));
        before.userFRAXBalance = frax.balanceOf(address(user1));
        before.moduleFRAXBalance = frax.balanceOf(address(_module));
        before.userPHOBalance = pho.balanceOf(user1);
        before.modulePHOBalance = pho.balanceOf(address(_module));
        before.userIssuedAmount = _module.issuedAmount(user1);
        before.totalPHOSupply = pho.totalSupply();

        // Deposit
        vm.warp(_depositTimestamp);
        vm.expectEmit(true, true, true, true);
        emit BondIssued(user1, _usdcDepositAmount, _fraxDepositAmount, _expectedMintAmount);
        vm.prank(user1);
        _module.deposit(_usdcDepositAmount, _fraxDepositAmount);

        // depositToken and PHO balances after
        DepositTokenBalance memory aft; // note that after is a reserved keyword
        aft.userUSDCBalance = usdc.balanceOf(address(user1));
        aft.moduleUSDCBalance = usdc.balanceOf(address(_module));
        aft.userFRAXBalance = frax.balanceOf(address(user1));
        aft.moduleFRAXBalance = frax.balanceOf(address(_module));
        aft.modulePHOBalance = pho.balanceOf(address(_module));
        aft.userPHOBalance = pho.balanceOf(user1);
        aft.userIssuedAmount = _module.issuedAmount(user1);
        aft.totalPHOSupply = pho.totalSupply();

        // User balance - PHO same and USDC & FRAX down
        assertEq(aft.userPHOBalance, before.userPHOBalance);
        assertEq(aft.userUSDCBalance, before.userUSDCBalance - usdcDepositAmount);
        assertEq(aft.userFRAXBalance, before.userFRAXBalance - fraxDepositAmount);

        // Frax BP Init module balance - PHO same, USDC & FRAX up
        assertEq(aft.modulePHOBalance, before.modulePHOBalance);
        assertEq(aft.moduleUSDCBalance, before.moduleUSDCBalance + usdcDepositAmount);
        assertEq(aft.moduleFRAXBalance, before.moduleFRAXBalance + fraxDepositAmount);

        // Check issued amount goes up
        assertEq(aft.userIssuedAmount, before.userIssuedAmount + _expectedMintAmount);

        // Check PHO supply stays same
        assertEq(aft.totalPHOSupply, before.totalPHOSupply);
    }

    // Cannot deposit if sale ended
    function testCannotDepositIfSaleEnded() public {
        vm.warp(saleEndDate + 1);

        vm.expectRevert(abi.encodeWithSelector(CannotDepositAfterSaleEnded.selector));
        vm.prank(user1);
        fraxBPInitModule.deposit(ONE_HUNDRED_D6, ONE_HUNDRED_D18);
    }

    // Helper function for testing adding FraxBP / PHO liquidity
    function _testAddFraxBPPHOLiquidity(uint256 usdcAmount, uint256 fraxAmount) public {
        uint256 usdcBalanceBefore = usdc.balanceOf(address(fraxBPInitModule));
        uint256 fraxBalanceBefore = frax.balanceOf(address(fraxBPInitModule));

        // Add to FraxBP/PHO
        fraxBPInitModule.addFraxBPPHOLiquidity(usdcAmount, fraxAmount);

        uint256 usdcBalanceAfter = usdc.balanceOf(address(fraxBPInitModule));
        uint256 fraxBalanceAfter = frax.balanceOf(address(fraxBPInitModule));
        uint256 fraxBPLPBalanceAfter = fraxBPLP.balanceOf(address(fraxBPInitModule));

        assertEq(fraxBPLPBalanceAfter, 0);
        assertEq(usdcBalanceAfter, usdcBalanceBefore - usdcAmount);
        assertEq(fraxBalanceAfter, fraxBalanceBefore - fraxAmount);
    }

    // Cannot add FraxBP / PHO liquidity if USDC/FRAX amounts imbalanced
    function testCannotAddFraxBPPHOLiquidityNonEqualAmounts() public {
        uint256 usdcDepositAmount = ONE_HUNDRED_D6;
        uint256 fraxDepositAmount = ONE_HUNDRED_D18;
        uint256 expectedMint = 2 * ONE_HUNDRED_D18;
        _testDepositAnyModule(
            usdcDepositAmount, fraxDepositAmount, expectedMint, fraxBPInitModule, saleEndDate - 500
        );

        // Add to FraxBP/PHO
        vm.expectRevert(abi.encodeWithSelector(MustHaveEqualAmounts.selector));
        fraxBPInitModule.addFraxBPPHOLiquidity(ONE_HUNDRED_D6 * 2, ONE_HUNDRED_D18);
    }

    // Test addFraxBPLiquidity()
    function testAddFraxBPPHOLiquidity() public {
        uint256 usdcDepositAmount = ONE_HUNDRED_D6;
        uint256 fraxDepositAmount = ONE_HUNDRED_D18;
        uint256 expectedMint = 2 * ONE_HUNDRED_D18;
        _testDepositAnyModule(
            usdcDepositAmount, fraxDepositAmount, expectedMint, fraxBPInitModule, saleEndDate - 500
        );

        _testAddFraxBPPHOLiquidity(ONE_HUNDRED_D6, ONE_HUNDRED_D18);

        uint256 redeemAmount = 2 * ONE_HUNDRED_D18;
        uint256 redeemTimestamp = block.timestamp;

        _testRedeemAnyModule(redeemAmount, fraxBPInitModule, redeemTimestamp);
    }

    // Basic redeem
    function testRedeemFull() public {
        uint256 usdcDepositAmount = ONE_HUNDRED_D6;
        uint256 fraxDepositAmount = ONE_HUNDRED_D18;
        uint256 expectedMint = 2 * ONE_HUNDRED_D18;
        _testDepositAnyModule(
            usdcDepositAmount, fraxDepositAmount, expectedMint, fraxBPInitModule, saleEndDate - 500
        );

        // Add liquidity to FraxBP / PHO pool
        _testAddFraxBPPHOLiquidity(ONE_HUNDRED_D6, ONE_HUNDRED_D18);

        uint256 redeemAmount = 2 * ONE_HUNDRED_D18;
        uint256 redeemTimestamp = block.timestamp;

        _testRedeemAnyModule(redeemAmount, fraxBPInitModule, redeemTimestamp);
    }

    // Helper function to test redeem from any FraxBPInitModule
    function _testRedeemAnyModule(
        uint256 _redeemAmount,
        FraxBPInitModule _module,
        uint256 _redeemTimestamp
    ) public {
        //uint256 usdcDepositAmount = _redeemAmount / 10**12;
        // USDC, FRAX and PHO balances before
        DepositTokenBalance memory before;
        before.userUSDCBalance = usdc.balanceOf(address(user1));
        before.moduleUSDCBalance = usdc.balanceOf(address(_module));
        before.userFRAXBalance = frax.balanceOf(address(user1));
        before.moduleFRAXBalance = frax.balanceOf(address(_module));
        before.userFraxBPLPBalance = fraxBPLP.balanceOf(user1);
        before.moduleFraxBPLPBalance = fraxBPLP.balanceOf(address(_module));
        before.userPHOBalance = pho.balanceOf(user1);
        before.modulePHOBalance = pho.balanceOf(address(_module));
        before.userIssuedAmount = _module.issuedAmount(user1);
        before.totalPHOSupply = pho.totalSupply();

        // Deposit
        vm.warp(_redeemTimestamp);
        vm.expectEmit(true, true, true, true);
        emit BondRedeemed(user1, _redeemAmount);
        vm.prank(user1);
        _module.redeem();

        // depositToken and PHO balances after
        DepositTokenBalance memory aft; // note that after is a reserved keyword
        aft.userUSDCBalance = usdc.balanceOf(address(user1));
        aft.moduleUSDCBalance = usdc.balanceOf(address(_module));
        aft.userFRAXBalance = frax.balanceOf(address(user1));
        aft.moduleFRAXBalance = frax.balanceOf(address(_module));
        aft.userFraxBPLPBalance = fraxBPLP.balanceOf(user1);
        aft.moduleFraxBPLPBalance = fraxBPLP.balanceOf(address(_module));
        aft.modulePHOBalance = pho.balanceOf(address(_module));
        aft.userPHOBalance = pho.balanceOf(user1);
        aft.userIssuedAmount = _module.issuedAmount(user1);
        aft.totalPHOSupply = pho.totalSupply();

        // User balance - FraxBPLP and PHO up, USDC/FRAX same
        assertApproxEqAbs(
            aft.userFraxBPLPBalance, before.userFraxBPLPBalance + _redeemAmount / 2, 10 ** 18
        );
        assertApproxEqAbs(aft.userPHOBalance, before.userPHOBalance + _redeemAmount / 2, 10 ** 18);
        assertEq(aft.userUSDCBalance, before.userUSDCBalance);
        assertEq(aft.userFRAXBalance, before.userFRAXBalance);

        // Frax BP Init module balance - FraxBPLP and PHO same, USDC & FRAX same
        assertEq(aft.moduleFraxBPLPBalance, before.moduleFraxBPLPBalance);
        assertEq(aft.modulePHOBalance, before.modulePHOBalance);
        assertEq(aft.moduleUSDCBalance, before.moduleUSDCBalance);
        assertEq(aft.moduleFRAXBalance, before.moduleFRAXBalance);

        // Check issued amount goes down
        assertEq(aft.userIssuedAmount, before.userIssuedAmount - _redeemAmount);

        // Check PHO supply same
        assertEq(aft.totalPHOSupply, before.totalPHOSupply);
    }
}
