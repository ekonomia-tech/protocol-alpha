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
    error CannotDepositAfterSaleEnded();
    error OnlyModuleManager();
    error CannotDepositZero();
    error InvalidTimeWindows();
    error CannotRedeemBeforeRedemptionStart();
    error CannotRedeemZero();

    /// Events
    event Deposited(address indexed depositor, uint256 fraxBPLpAmount, uint256 phoAmount);
    event Redeemed(
        address indexed redeemer, uint256 redeemAmount, uint256 fraxBPLPAmount, uint256 phoAmount
    );

    ICurvePool public fraxBPPHOMetapool;
    FraxBPInitModule public fraxBPInitModule;

    /// Constants
    string public FRAX_BP_BOND_TOKEN_NAME = "FraxBP-3mo";
    string public FRAX_BP_BOND_TOKEN_SYMBOL = "FRAXBP-3M";
    uint256 public constant USDC_SCALE = 10 ** 12;
    uint256 public constant maxCap = 20000000 * 10 ** 18;
    uint256 public saleEndDate;
    uint256 public redemptionStartDate;

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

        _getFRAX(user2, ONE_MILLION_D18);
        _getUSDC(user2, ONE_MILLION_D6);

        // Update oracle
        vm.startPrank(owner);
        priceFeed.addFeed(FRAX_ADDRESS, PRICEFEED_FRAXUSD);
        priceFeed.addFeed(USDC_ADDRESS, PRICEFEED_USDCUSD);
        vm.stopPrank();

        fraxBPPHOMetapool = ICurvePool(_deployFraxBPPHOPoolCustom(20));

        //_deployFraxBPPHOPoolCustom
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
        uint256 expectedMint = 2 * fraxDepositAmount;
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
        DepositTokenBalance memory before;
        before.userUSDCBalance = usdc.balanceOf(user);
        before.moduleUSDCBalance = usdc.balanceOf(address(_module));
        before.userFRAXBalance = frax.balanceOf(user);
        before.moduleFRAXBalance = frax.balanceOf(address(_module));
        before.userFraxBPLPBalance = fraxBPLP.balanceOf(user);
        before.moduleFraxBPLPBalance = fraxBPLP.balanceOf(address(_module));
        before.userPHOBalance = pho.balanceOf(user);
        before.modulePHOBalance = pho.balanceOf(address(_module));
        before.userIssuedAmount = _module.issuedAmount(user);
        before.totalPHOSupply = pho.totalSupply();

        // Deposit - event topic check false since FraxBPLP amount is not precomputed here
        vm.warp(_depositTimestamp);
        vm.expectEmit(true, false, false, false);
        emit Deposited(user, _usdcDepositAmount, _fraxDepositAmount);
        vm.prank(user);
        _module.depositHelper(_usdcDepositAmount, _fraxDepositAmount);

        // depositToken and PHO balances after
        DepositTokenBalance memory aft; // note that after is a reserved keyword
        aft.userUSDCBalance = usdc.balanceOf(user);
        aft.moduleUSDCBalance = usdc.balanceOf(address(_module));
        aft.userFRAXBalance = frax.balanceOf(user);
        aft.moduleFRAXBalance = frax.balanceOf(address(_module));
        aft.userFraxBPLPBalance = fraxBPLP.balanceOf(user);
        aft.moduleFraxBPLPBalance = fraxBPLP.balanceOf(address(_module));
        aft.modulePHOBalance = pho.balanceOf(address(_module));
        aft.userPHOBalance = pho.balanceOf(user);
        aft.userIssuedAmount = _module.issuedAmount(user);
        aft.totalPHOSupply = pho.totalSupply();

        uint256 moduleFraxBPLPDiff = aft.moduleFraxBPLPBalance - before.moduleFraxBPLPBalance;
        uint256 getUSDPerFraxBP = _module.getUSDPerFraxBP();
        uint256 expectedPHOAmount = (getUSDPerFraxBP * moduleFraxBPLPDiff) / 10 ** 18;

        // User balance - PHO balance same and USDC & FRAX down
        assertEq(aft.userPHOBalance, before.userPHOBalance);
        assertEq(aft.userUSDCBalance, before.userUSDCBalance - usdcDepositAmount);
        assertEq(aft.userFRAXBalance, before.userFRAXBalance - fraxDepositAmount);

        // Frax BP Init module balance - PHO up, USDC & FRAX same
        assertEq(aft.modulePHOBalance, before.modulePHOBalance + expectedPHOAmount);
        assertEq(aft.moduleUSDCBalance, before.moduleUSDCBalance);
        assertEq(aft.moduleFRAXBalance, before.moduleFRAXBalance);

        // Check issued amount goes up
        assertApproxEqAbs(
            aft.userIssuedAmount,
            before.userIssuedAmount + _expectedMintAmount,
            deltaThreshold * 10 ** 18
        );

        // // Check PHO supply goes up
        assertEq(aft.totalPHOSupply, before.totalPHOSupply + expectedPHOAmount);
    }

    // Cannot add liquidity unless moduleManager
    function testCannotAddLiquidityOnlyModuleManager() public {
        vm.warp(redemptionStartDate + 1);

        vm.expectRevert(abi.encodeWithSelector(OnlyModuleManager.selector));
        vm.prank(user1);
        fraxBPInitModule.addFraxBPPHOLiquidity();
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
        uint256 expectedMint = 2 * ONE_HUNDRED_D18;
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
        uint256 expectedMint2 = 2 * TEN_THOUSAND_D18;
        _testDepositAnyModule(
            user2,
            usdcDepositAmount2,
            fraxDepositAmount2,
            expectedMint2,
            fraxBPInitModule,
            saleEndDate - 400,
            15
        );

        vm.prank(address(moduleManager));
        fraxBPInitModule.addFraxBPPHOLiquidity();

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
        DepositTokenBalance memory before;
        before.userUSDCBalance = usdc.balanceOf(user);
        before.moduleUSDCBalance = usdc.balanceOf(address(_module));
        before.userFRAXBalance = frax.balanceOf(user);
        before.moduleFRAXBalance = frax.balanceOf(address(_module));
        before.userFraxBPLPBalance = fraxBPLP.balanceOf(user);
        before.moduleFraxBPLPBalance = fraxBPLP.balanceOf(address(_module));
        before.userPHOBalance = pho.balanceOf(user);
        before.modulePHOBalance = pho.balanceOf(address(_module));
        before.userIssuedAmount = _module.issuedAmount(user);
        before.totalPHOSupply = pho.totalSupply();

        uint256 getUSDPerFraxBP = _module.getUSDPerFraxBP();
        uint256 redeemAmount = _module.issuedAmount(user);
        uint256 expectedPHOAmountBurnt = (redeemAmount * 10 ** 18) / getUSDPerFraxBP;

        // Redeem - note for event, amounts are not exact,
        vm.warp(_redeemTimestamp);
        vm.expectEmit(true, false, false, false);
        emit Redeemed(user, redeemAmount, before.userIssuedAmount / 2, before.userIssuedAmount / 2);
        vm.prank(user);
        _module.redeem();

        // depositToken and PHO balances after
        DepositTokenBalance memory aft; // note that after is a reserved keyword
        aft.userUSDCBalance = usdc.balanceOf(user);
        aft.moduleUSDCBalance = usdc.balanceOf(address(_module));
        aft.userFRAXBalance = frax.balanceOf(user);
        aft.moduleFRAXBalance = frax.balanceOf(address(_module));
        aft.userFraxBPLPBalance = fraxBPLP.balanceOf(user);
        aft.moduleFraxBPLPBalance = fraxBPLP.balanceOf(address(_module));
        aft.modulePHOBalance = pho.balanceOf(address(_module));
        aft.userPHOBalance = pho.balanceOf(user);
        aft.userIssuedAmount = _module.issuedAmount(user);
        aft.totalPHOSupply = pho.totalSupply();

        uint256 moduleFraxBPLPDiff = before.moduleFraxBPLPBalance - aft.moduleFraxBPLPBalance;

        // User balance - FraxBPLP and PHO up (~issuedAmount / 2), USDC/FRAX same
        assertApproxEqAbs(
            aft.userFraxBPLPBalance, before.userIssuedAmount / 2, deltaThreshold * 10 ** 18
        );
        assertApproxEqAbs(
            aft.userPHOBalance, before.userIssuedAmount / 2, deltaThreshold * 10 ** 18
        );
        assertEq(aft.userUSDCBalance, before.userUSDCBalance);
        assertEq(aft.userFRAXBalance, before.userFRAXBalance);

        // Frax BP Init module balance - FraxBPLP and PHO same, USDC & FRAX same
        assertEq(aft.moduleFraxBPLPBalance, before.moduleFraxBPLPBalance);
        assertEq(aft.modulePHOBalance, before.modulePHOBalance);
        assertEq(aft.moduleUSDCBalance, before.moduleUSDCBalance);
        assertEq(aft.moduleFRAXBalance, before.moduleFRAXBalance);

        // Check issued amount goes down
        assertEq(aft.userIssuedAmount, 0);

        // Check PHO supply same
        assertEq(aft.totalPHOSupply, before.totalPHOSupply);
    }
}
