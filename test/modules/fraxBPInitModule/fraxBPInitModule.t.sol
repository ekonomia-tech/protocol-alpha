// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../../BaseSetup.t.sol";
import "@external/curve/ICurvePool.sol";
import "@external/curve/ICurveFactory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@modules/priceController/PriceController.sol";
import "@modules/fraxBPInitModule/FraxBPInitModule.sol";
import "forge-std/console2.sol";

contract FraxBPInitModuleTest is BaseSetup {
    /// Errors
    error ZeroAddressDetected();
    error CannotDepositAfterSaleEnded();
    error OnlyModuleManager();
    error CannotDepositZero();
    error InvalidTimeWindows();
    error CannotRedeemBeforeRedemptionStart();
    error CannotRedeemZero();

    /// Events
    event Deposited(address indexed depositor, uint256 fraxBPLpAmount, uint256 phoAmount);
    event Redeemed(address indexed redeemer, uint256 redeemAmount);

    ICurvePool public fraxBPPHOMetapool;
    FraxBPInitModule public fraxBPInitModule;

    /// Constants
    uint256 public saleEndDate;
    uint256 public redemptionStartDate;

    // Track balance for FRAX, USDC, FRAXBP LP, & PHO
    struct TokenBalances {
        uint256 userUSDCBalance;
        uint256 moduleUSDCBalance;
        uint256 userFRAXBalance;
        uint256 moduleFRAXBalance;
        uint256 userFraxBPLPBalance;
        uint256 userFraxBPPHOLPBalance;
        uint256 moduleFraxBPLPBalance;
        uint256 userPHOBalance;
        uint256 modulePHOBalance;
        uint256 moduleFraxBPPHOLPBalance;
        uint256 userMetapoolBalance;
        uint256 totalPHOSupply;
    }

    function setUp() public {
        fraxBPLP = IERC20(FRAXBP_LP_TOKEN);
        curveFactory = ICurveFactory(metaPoolFactoryAddress);

        // Give user FRAX and USDC
        _getFRAX(user1, TEN_THOUSAND_D18);
        _getUSDC(user1, TEN_THOUSAND_D6);

        _getFRAX(user2, ONE_MILLION_D18);
        _getUSDC(user2, ONE_MILLION_D6);

        // Update oracle
        vm.startPrank(owner);
        priceFeed.addFeed(FRAX_ADDRESS, PRICEFEED_FRAXUSD);
        priceFeed.addFeed(USDC_ADDRESS, PRICEFEED_USDCUSD);
        vm.stopPrank();

        // Frax BP / PHO metapool
        fraxBPPHOMetapool = ICurvePool(_deployFraxBPPHOPoolCustom(20));

        saleEndDate = block.timestamp + 10000;
        redemptionStartDate = block.timestamp + 20000;

        vm.prank(owner);
        fraxBPInitModule = new FraxBPInitModule(
            address(moduleManager),
            address(fraxBPPHOMetapool),
            address(pho),
            address(priceFeed),
            saleEndDate,
            redemptionStartDate
        );

        vm.prank(PHOGovernance);
        moduleManager.addModule(address(fraxBPInitModule));

        vm.prank(TONGovernance);
        moduleManager.setPHOCeilingForModule(address(fraxBPInitModule), ONE_MILLION_D18 * 100);

        vm.warp(block.timestamp + moduleManager.moduleDelay());
        moduleManager.executeCeilingUpdate(address(fraxBPInitModule));

        // Approve sending USDC to FraxBP Init Module
        vm.startPrank(user1);
        usdc.approve(address(fraxBPInitModule), TEN_THOUSAND_D6);
        frax.approve(address(fraxBPInitModule), TEN_THOUSAND_D18);
        fraxBPLP.approve(address(fraxBPInitModule), TEN_THOUSAND_D18);
        pho.approve(address(fraxBPInitModule), TEN_THOUSAND_D18);
        pho.approve(address(kernel), ONE_MILLION_D18);
        vm.stopPrank();
        vm.startPrank(user2);
        usdc.approve(address(fraxBPInitModule), ONE_MILLION_D6);
        frax.approve(address(fraxBPInitModule), ONE_MILLION_D18);
        fraxBPLP.approve(address(fraxBPInitModule), ONE_MILLION_D18);
        vm.stopPrank();
    }

    // Cannot set addresses to 0
    function testCannotMakeFraxBpModuleWithZeroAddress() public {
        vm.startPrank(user1);
        // ModuleManager
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        fraxBPInitModule = new FraxBPInitModule(
            address(0),
            address(fraxBPPHOMetapool),
            address(pho),
            address(priceFeed),
            saleEndDate,
            redemptionStartDate
        );

        // Frax BP / PHO Pool
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        fraxBPInitModule = new FraxBPInitModule(
            address(moduleManager),
            address(0),
            address(pho),
            address(priceFeed),
            saleEndDate,
            redemptionStartDate
        );

        // PHO
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        fraxBPInitModule = new FraxBPInitModule(
            address(moduleManager),
            address(fraxBPPHOMetapool),
            address(0),
            address(priceFeed),
            saleEndDate,
            redemptionStartDate
        );

        // Oracle
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        fraxBPInitModule = new FraxBPInitModule(
            address(moduleManager),
            address(fraxBPPHOMetapool),
            address(pho),
            address(0),
            saleEndDate,
            redemptionStartDate
        );

        vm.stopPrank();
    }

    // Cannot set time windows as invalid
    function testCannotMakeFraxBpModuleWithInvalidTimeWindows() public {
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(InvalidTimeWindows.selector));
        fraxBPInitModule = new FraxBPInitModule(
            address(moduleManager),
            address(fraxBPPHOMetapool),
            address(pho),
            address(priceFeed),
            block.timestamp - 1,
            redemptionStartDate
        );

        vm.expectRevert(abi.encodeWithSelector(InvalidTimeWindows.selector));
        fraxBPInitModule = new FraxBPInitModule(
            address(moduleManager),
            address(fraxBPPHOMetapool),
            address(pho),
            address(priceFeed),
            saleEndDate,
            saleEndDate
        );

        vm.stopPrank();
    }

    // Cannot deposit if sale ended
    function testCannotDepositIfSaleEnded() public {
        vm.warp(saleEndDate + 1);

        vm.expectRevert(abi.encodeWithSelector(CannotDepositAfterSaleEnded.selector));
        vm.prank(user1);
        fraxBPInitModule.depositHelper(ONE_HUNDRED_D6, ONE_HUNDRED_D18);
    }

    // Cannot deposit zero
    function testCannotDepositZero() public {
        vm.warp(saleEndDate - 1);

        vm.expectRevert(abi.encodeWithSelector(CannotDepositZero.selector));
        vm.prank(user1);
        fraxBPInitModule.depositHelper(0, 0);
    }

    // Basic deposit
    function testDepositFull() public {
        uint256 usdcDepositAmount = ONE_HUNDRED_D6;
        uint256 fraxDepositAmount = ONE_HUNDRED_D18;
        uint256 expectedMint = 4 * fraxDepositAmount; // ~200D18 of FraxBP, equivalent amount of PHO = 4x
        _testDepositAnyModule(
            user1,
            usdcDepositAmount,
            fraxDepositAmount,
            expectedMint,
            fraxBPInitModule,
            saleEndDate - 500,
            1
        );
    }

    // Helper function to test deposit from any FraxBPInitModule
    function _testDepositAnyModule(
        address user,
        uint256 _usdcDepositAmount,
        uint256 _fraxDepositAmount,
        uint256 _expectedMintAmount,
        FraxBPInitModule _module,
        uint256 _depositTimestamp,
        uint256 deltaThreshold
    ) public {
        uint256 usdcDepositAmount = _usdcDepositAmount;
        uint256 fraxDepositAmount = _fraxDepositAmount;
        // USDC, FRAX and PHO balances before
        TokenBalances memory before;
        before.userUSDCBalance = usdc.balanceOf(user);
        before.moduleUSDCBalance = usdc.balanceOf(address(_module));
        before.userFRAXBalance = frax.balanceOf(user);
        before.moduleFRAXBalance = frax.balanceOf(address(_module));
        before.userFraxBPLPBalance = fraxBPLP.balanceOf(user);
        before.moduleFraxBPLPBalance = fraxBPLP.balanceOf(address(_module));
        before.userFraxBPPHOLPBalance = fraxBPPHOMetapool.balanceOf(user);
        before.moduleFraxBPPHOLPBalance = fraxBPPHOMetapool.balanceOf(address(_module));
        before.userPHOBalance = pho.balanceOf(user);
        before.modulePHOBalance = pho.balanceOf(address(_module));
        before.userMetapoolBalance = _module.metapoolBalance(user);
        before.totalPHOSupply = pho.totalSupply();

        // Deposit - event topic check false since FraxBPLP amount is not precomputed here
        vm.warp(_depositTimestamp);
        vm.expectEmit(true, false, false, false);
        emit Deposited(user, _usdcDepositAmount, _fraxDepositAmount);
        vm.prank(user);
        _module.depositHelper(_usdcDepositAmount, _fraxDepositAmount);

        // depositToken and PHO balances after
        TokenBalances memory aft; // note that after is a reserved keyword
        aft.userUSDCBalance = usdc.balanceOf(user);
        aft.moduleUSDCBalance = usdc.balanceOf(address(_module));
        aft.userFRAXBalance = frax.balanceOf(user);
        aft.moduleFRAXBalance = frax.balanceOf(address(_module));
        aft.userFraxBPLPBalance = fraxBPLP.balanceOf(user);
        aft.moduleFraxBPLPBalance = fraxBPLP.balanceOf(address(_module));
        aft.userFraxBPPHOLPBalance = fraxBPPHOMetapool.balanceOf(user);
        aft.moduleFraxBPPHOLPBalance = fraxBPPHOMetapool.balanceOf(address(_module));
        aft.modulePHOBalance = pho.balanceOf(address(_module));
        aft.userPHOBalance = pho.balanceOf(user);
        aft.userMetapoolBalance = _module.metapoolBalance(user);
        aft.totalPHOSupply = pho.totalSupply();

        uint256 moduleFraxBPLPDiff = aft.moduleFraxBPLPBalance - before.moduleFraxBPLPBalance;
        uint256 getUSDPerFraxBP = _module.getUSDPerFraxBP();
        uint256 expectedPHOAmount = _expectedMintAmount / 2; // approx

        // User balance - PHO balance same and USDC & FRAX down, FraxBPPHO LP same
        assertEq(aft.userPHOBalance, before.userPHOBalance);
        assertEq(aft.userUSDCBalance, before.userUSDCBalance - usdcDepositAmount);
        assertEq(aft.userFRAXBalance, before.userFRAXBalance - fraxDepositAmount);
        assertEq(aft.userFraxBPPHOLPBalance, before.userFraxBPPHOLPBalance);

        // Frax BP Init module balance - PHO same, USDC & FRAX same, FraxBPPHO LP up
        assertEq(aft.modulePHOBalance, before.modulePHOBalance);
        assertEq(aft.moduleUSDCBalance, before.moduleUSDCBalance);
        assertEq(aft.moduleFRAXBalance, before.moduleFRAXBalance);
        assertApproxEqAbs(
            aft.moduleFraxBPPHOLPBalance,
            before.moduleFraxBPPHOLPBalance + _expectedMintAmount,
            deltaThreshold * 10 ** 18
        );

        // Check issued amount goes up
        assertApproxEqAbs(
            aft.userMetapoolBalance,
            before.userMetapoolBalance + _expectedMintAmount,
            deltaThreshold * 10 ** 18
        );

        // Check PHO supply goes up
        assertApproxEqAbs(
            aft.totalPHOSupply, before.totalPHOSupply + expectedPHOAmount, deltaThreshold * 10 ** 18
        );
    }

    // Cannot redeem before redemption start
    function testCannotRedeemBeforeRedemptionStart() public {
        vm.warp(redemptionStartDate - 1);

        vm.expectRevert(abi.encodeWithSelector(CannotRedeemBeforeRedemptionStart.selector));
        vm.prank(user1);
        fraxBPInitModule.redeem();
    }

    // Cannot redeem zero
    function testCannotRedeemZero() public {
        vm.warp(redemptionStartDate + 1);

        vm.expectRevert(abi.encodeWithSelector(CannotRedeemZero.selector));
        vm.prank(user1);
        fraxBPInitModule.redeem();
    }

    // Basic redeem
    function testRedeemFull() public {
        uint256 usdcDepositAmount = ONE_HUNDRED_D6;
        uint256 fraxDepositAmount = ONE_HUNDRED_D18;
        uint256 expectedMint = 4 * ONE_HUNDRED_D18;
        _testDepositAnyModule(
            user1,
            usdcDepositAmount,
            fraxDepositAmount,
            expectedMint,
            fraxBPInitModule,
            saleEndDate - 500,
            1
        );

        uint256 usdcDepositAmount2 = TEN_THOUSAND_D6;
        uint256 fraxDepositAmount2 = TEN_THOUSAND_D18;
        uint256 expectedMint2 = 4 * TEN_THOUSAND_D18;
        _testDepositAnyModule(
            user2,
            usdcDepositAmount2,
            fraxDepositAmount2,
            expectedMint2,
            fraxBPInitModule,
            saleEndDate - 400,
            15
        );

        uint256 redeemAmount = 2 * ONE_HUNDRED_D18;
        uint256 redeemTimestamp = redemptionStartDate + 1;

        _testRedeemAnyModule(user1, redeemAmount, fraxBPInitModule, redeemTimestamp, 1);
    }

    // Helper function to test redeem from any FraxBPInitModule
    function _testRedeemAnyModule(
        address user,
        uint256 _redeemAmount,
        FraxBPInitModule _module,
        uint256 _redeemTimestamp,
        uint256 deltaThreshold
    ) public {
        // USDC, FRAX and PHO balances before
        TokenBalances memory before;
        before.userUSDCBalance = usdc.balanceOf(user);
        before.moduleUSDCBalance = usdc.balanceOf(address(_module));
        before.userFRAXBalance = frax.balanceOf(user);
        before.moduleFRAXBalance = frax.balanceOf(address(_module));
        before.userFraxBPLPBalance = fraxBPLP.balanceOf(user);
        before.moduleFraxBPLPBalance = fraxBPLP.balanceOf(address(_module));
        before.userFraxBPPHOLPBalance = fraxBPPHOMetapool.balanceOf(user);
        before.moduleFraxBPPHOLPBalance = fraxBPPHOMetapool.balanceOf(address(_module));
        before.userPHOBalance = pho.balanceOf(user);
        before.modulePHOBalance = pho.balanceOf(address(_module));
        before.userMetapoolBalance = _module.metapoolBalance(user);
        before.totalPHOSupply = pho.totalSupply();

        uint256 getUSDPerFraxBP = _module.getUSDPerFraxBP();
        uint256 redeemAmount = _module.metapoolBalance(user);
        uint256 expectedPHOAmountBurnt = (redeemAmount * 10 ** 18) / getUSDPerFraxBP;

        // Redeem - note for event, amounts are not exact,
        vm.warp(_redeemTimestamp);
        vm.expectEmit(true, false, false, false);
        emit Redeemed(user, redeemAmount);
        vm.prank(user);
        _module.redeem();

        // depositToken and PHO balances after
        TokenBalances memory aft; // note that after is a reserved keyword
        aft.userUSDCBalance = usdc.balanceOf(user);
        aft.moduleUSDCBalance = usdc.balanceOf(address(_module));
        aft.userFRAXBalance = frax.balanceOf(user);
        aft.moduleFRAXBalance = frax.balanceOf(address(_module));
        aft.userFraxBPLPBalance = fraxBPLP.balanceOf(user);
        aft.moduleFraxBPLPBalance = fraxBPLP.balanceOf(address(_module));
        aft.userFraxBPPHOLPBalance = fraxBPPHOMetapool.balanceOf(user);
        aft.moduleFraxBPPHOLPBalance = fraxBPPHOMetapool.balanceOf(address(_module));
        aft.modulePHOBalance = pho.balanceOf(address(_module));
        aft.userPHOBalance = pho.balanceOf(user);
        aft.userMetapoolBalance = _module.metapoolBalance(user);
        aft.totalPHOSupply = pho.totalSupply();

        uint256 moduleFraxBPLPDiff = before.moduleFraxBPLPBalance - aft.moduleFraxBPLPBalance;

        // User balance - FraxBPPHO LP up (~metapoolBalance / 2), FraxBP LP, PHO, USDC/FRAX same
        assertApproxEqAbs(
            aft.userFraxBPPHOLPBalance, before.userMetapoolBalance / 2, deltaThreshold * 10 ** 18
        );
        assertEq(aft.userFraxBPLPBalance, before.userFraxBPLPBalance);
        assertEq(aft.userPHOBalance, before.userPHOBalance);
        assertEq(aft.userUSDCBalance, before.userUSDCBalance);
        assertEq(aft.userFRAXBalance, before.userFRAXBalance);

        // Frax BP Init module balance - FraxBPPHO LP down, FraxBPLP and PHO same, USDC & FRAX same
        assertApproxEqAbs(
            aft.moduleFraxBPPHOLPBalance,
            before.moduleFraxBPPHOLPBalance - before.userMetapoolBalance / 2,
            deltaThreshold * 10 ** 18
        );
        assertEq(aft.moduleFraxBPLPBalance, before.moduleFraxBPLPBalance);
        assertEq(aft.modulePHOBalance, before.modulePHOBalance);
        assertEq(aft.moduleUSDCBalance, before.moduleUSDCBalance);
        assertEq(aft.moduleFRAXBalance, before.moduleFRAXBalance);

        // Check issued amount goes down
        assertEq(aft.userMetapoolBalance, 0);

        // Check PHO supply same
        assertEq(aft.totalPHOSupply, before.totalPHOSupply);
    }
}
