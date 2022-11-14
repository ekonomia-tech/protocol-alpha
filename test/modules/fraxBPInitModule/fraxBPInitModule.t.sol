// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../../BaseSetup.t.sol";
import "@external/curve/ICurvePool.sol";
import "@external/curve/ICurveFactory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@modules/priceController/PriceController.sol";
import "@modules/fraxBpInitModule/FraxBPInitModule.sol";
import "forge-std/console2.sol";

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
    event BondIssued(address indexed depositor, uint256 depositAmount, uint256 mintAmount);
    event BondRedeemed(address indexed redeemer, uint256 redeemAmount);

    ICurvePool public fraxBPPHOMetapool;
    FraxBPInitModule public fraxBPInitModule;

    /// Constants
    string public FRAX_BP_BOND_TOKEN_NAME = "FraxBP-3mo";
    string public FRAX_BP_BOND_TOKEN_SYMBOL = "FRAXBP-3M";
    uint256 public constant USDC_SCALE = 10 ** 12;
    uint256 public constant maxCap = 20000000 * 10 ** 18;

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
        fraxBP = ICurvePool(FRAXBP_ADDRESS);
        curveFactory = ICurveFactory(metaPoolFactoryAddress);

        // Give user FRAX and USDC
        _getFRAX(user1, TEN_THOUSAND_D18);
        _getUSDC(user1, TEN_THOUSAND_D6);

        fraxBPPHOMetapool = ICurvePool(_deployFraxBPPHOPoolCustom(20));

        //_deployFraxBPPHOPoolCustom

        vm.prank(owner);
        fraxBPInitModule = new FraxBPInitModule(
            address(moduleManager),
            address(kernel),
            FRAX_BP_BOND_TOKEN_NAME,
            FRAX_BP_BOND_TOKEN_SYMBOL,
            address(frax),
            address(usdc),
            address(fraxBPLP),
            address(fraxBP),
            address(pho),
            maxCap
        );

        vm.prank(PHOGovernance);
        moduleManager.addModule(address(fraxBPInitModule));

        vm.prank(TONGovernance);
        moduleManager.setPHOCeilingForModule(address(fraxBPInitModule), ONE_MILLION_D18 * 10);

        vm.warp(block.timestamp + moduleManager.moduleDelay());
        moduleManager.executeCeilingUpdate(address(fraxBPInitModule));

        vm.prank(address(fraxBPInitModule));
        moduleManager.mintPHO(address(fraxBPInitModule), ONE_HUNDRED_THOUSAND_D18);

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
            address(frax),
            address(usdc),
            address(fraxBPLP),
            address(fraxBP),
            address(pho),
            maxCap
        );

        // Kernel
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        fraxBPInitModule = new FraxBPInitModule(
            address(moduleManager),
            address(0),
            FRAX_BP_BOND_TOKEN_NAME,
            FRAX_BP_BOND_TOKEN_SYMBOL,
            address(frax),
            address(usdc),
            address(fraxBPLP),
            address(fraxBP),
            address(pho),
            maxCap
        );

        // FRAX
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        fraxBPInitModule = new FraxBPInitModule(
            address(moduleManager),
            address(kernel),
            FRAX_BP_BOND_TOKEN_NAME,
            FRAX_BP_BOND_TOKEN_SYMBOL,
            address(0),
            address(usdc),
            address(fraxBPLP),
            address(fraxBP),
            address(pho),
            maxCap
        );

        // USDC
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        fraxBPInitModule = new FraxBPInitModule(
            address(moduleManager),
            address(kernel),
            FRAX_BP_BOND_TOKEN_NAME,
            FRAX_BP_BOND_TOKEN_SYMBOL,
            address(frax),
            address(0),
            address(fraxBPLP),
            address(fraxBP),
            address(pho),
            maxCap
        );

        // FRAX BP LP
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        fraxBPInitModule = new FraxBPInitModule(
            address(moduleManager),
            address(kernel),
            FRAX_BP_BOND_TOKEN_NAME,
            FRAX_BP_BOND_TOKEN_SYMBOL,
            address(frax),
            address(usdc),
            address(0),
            address(fraxBP),
            address(pho),
            maxCap
        );

        // FRAX BP Pool
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        fraxBPInitModule = new FraxBPInitModule(
            address(moduleManager),
            address(kernel),
            FRAX_BP_BOND_TOKEN_NAME,
            FRAX_BP_BOND_TOKEN_SYMBOL,
            address(frax),
            address(usdc),
            address(fraxBPLP),
            address(0),
            address(pho),
            maxCap
        );

        // PHO
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        fraxBPInitModule = new FraxBPInitModule(
            address(moduleManager),
            address(kernel),
            FRAX_BP_BOND_TOKEN_NAME,
            FRAX_BP_BOND_TOKEN_SYMBOL,
            address(frax),
            address(usdc),
            address(fraxBPLP),
            address(fraxBP),
            address(0),
            maxCap
        );

        vm.stopPrank();
    }

    // Basic deposit
    function testDepositFull() public {
        uint256 depositAmount = ONE_HUNDRED_D18;
        uint256 expectedMint = depositAmount;
        _testDepositAnyModule(depositAmount, expectedMint, fraxBPInitModule, block.timestamp);
    }

    // Helper function to test deposit from any FraxBPInitModule
    function _testDepositAnyModule(
        uint256 _depositAmount,
        uint256 _expectedMintAmount,
        FraxBPInitModule _module,
        uint256 _depositTimestamp
    ) public {
        uint256 usdcDepositAmount = _depositAmount / 10 ** 12;
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
        emit BondIssued(user1, _depositAmount, _expectedMintAmount);
        vm.prank(user1);
        _module.deposit(_depositAmount);

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
        assertEq(aft.userFRAXBalance, before.userFRAXBalance - _depositAmount);

        // Frax BP Init module balance - PHO same, USDC & FRAX up
        assertEq(aft.modulePHOBalance, before.modulePHOBalance);
        assertEq(aft.moduleUSDCBalance, before.moduleUSDCBalance + usdcDepositAmount);
        assertEq(aft.moduleFRAXBalance, before.moduleFRAXBalance + _depositAmount);

        // Check issued amount goes up
        assertEq(aft.userIssuedAmount, before.userIssuedAmount + _expectedMintAmount);

        // Check PHO supply stays same
        assertEq(aft.totalPHOSupply, before.totalPHOSupply);
    }

    // Cannot set sale ended if not owner
    function testCannotSetSaleEndedOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        fraxBPInitModule.setSaleEnded(true);
    }

    // Cannot deposit if sale ended
    function testCannotDepositIfSaleEnded() public {
        vm.prank(owner);
        fraxBPInitModule.setSaleEnded(true);

        vm.expectRevert(abi.encodeWithSelector(CannotDepositAfterSaleEnded.selector));
        vm.prank(user1);
        fraxBPInitModule.deposit(ONE_HUNDRED_D18);
    }

    // Cannot set FraxBP/PHO pool if not owner
    function testCannotSetFraxBpPHOPoolOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        fraxBPInitModule.setFraxBpPHOPool(address(0));
    }

    // Cannot set FraxBP/PHO pool to 0
    function testCannotSetFraxBpPHOPoolZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        fraxBPInitModule.setFraxBpPHOPool(address(0));
    }

    // Test basic set FraxBP/PHO phool
    function testSetFraxBpPHOPool() public {
        vm.prank(owner);
        fraxBPInitModule.setFraxBpPHOPool(address(fraxBPPHOMetapool));
    }

    // Helper function for adding USDC/FRAX to FraxBP pool
    function _testAddFraxBPLiquidity(uint256 usdcAmount, uint256 fraxAmount) public {
        uint256 usdcBalanceBefore = usdc.balanceOf(address(fraxBPInitModule));
        uint256 fraxBalanceBefore = frax.balanceOf(address(fraxBPInitModule));

        vm.prank(owner);
        fraxBPInitModule.addFraxBPLiquidity(usdcAmount, fraxAmount);

        uint256 usdcBalanceAfter = usdc.balanceOf(address(fraxBPInitModule));
        uint256 fraxBalanceAfter = frax.balanceOf(address(fraxBPInitModule));

        assertEq(usdcBalanceAfter, usdcBalanceBefore - usdcAmount);
        assertEq(fraxBalanceAfter, fraxBalanceBefore - fraxAmount);
    }

    // Test addFraxBPLiquidity()
    function testAddFraxBPLiquidity() public {
        uint256 depositAmount = ONE_HUNDRED_D18;
        uint256 expectedMint = depositAmount;
        _testDepositAnyModule(depositAmount, expectedMint, fraxBPInitModule, block.timestamp);
        _testAddFraxBPLiquidity(ONE_HUNDRED_D6, ONE_HUNDRED_D18);
    }

    // Helper function for testing adding FraxBP / PHO liquidity
    function _testAddFraxBPPHOLiquidity() public {
        uint256 fraxBPLPBalanceBefore = fraxBPLP.balanceOf(address(fraxBPInitModule));

        vm.prank(owner);
        fraxBPInitModule.setFraxBpPHOPool(address(fraxBPPHOMetapool));

        // Add to FraxBP/PHO
        fraxBPInitModule.addFraxBPPHOLiquidity(
            fraxBPLPBalanceBefore, ONE_HUNDRED_D6, ONE_HUNDRED_D18
        );

        uint256 fraxBPLPBalanceAfter = fraxBPLP.balanceOf(address(fraxBPInitModule));
        assertEq(fraxBPLPBalanceAfter, 0);
    }

    // Cannot add FraxBP / PHO liquidity if USDC/FRAX amounts imbalanced
    function testCannotAddFraxBPPHOLiquidityNonEqualAmounts() public {
        uint256 fraxBPLPBalanceBefore = fraxBPLP.balanceOf(address(fraxBPInitModule));

        vm.prank(owner);
        fraxBPInitModule.setFraxBpPHOPool(address(fraxBPPHOMetapool));

        // Add to FraxBP/PHO
        vm.expectRevert(abi.encodeWithSelector(MustHaveEqualAmounts.selector));
        fraxBPInitModule.addFraxBPPHOLiquidity(
            fraxBPLPBalanceBefore, ONE_HUNDRED_D6 * 2, ONE_HUNDRED_D18
        );
    }

    // Test addFraxBPLiquidity()
    function testAddFraxBPPHOLiquidity() public {
        uint256 depositAmount = 2 * ONE_HUNDRED_D18;
        uint256 expectedMint = depositAmount;
        _testDepositAnyModule(depositAmount, expectedMint, fraxBPInitModule, block.timestamp);

        _testAddFraxBPLiquidity(ONE_HUNDRED_D6, ONE_HUNDRED_D18);

        _testAddFraxBPPHOLiquidity();

        uint256 redeemAmount = 2 * ONE_HUNDRED_D18;
        uint256 redeemTimestamp = block.timestamp;

        _testRedeemAnyModule(redeemAmount, fraxBPInitModule, redeemTimestamp);
    }

    // Basic redeem
    function testCannotRedeemFraxBPPHOMetapoolNotSet() public {
        uint256 depositAmount = ONE_HUNDRED_D18;
        uint256 expectedMint = depositAmount;
        _testDepositAnyModule(depositAmount, expectedMint, fraxBPInitModule, block.timestamp);

        uint256 redeemAmount = ONE_HUNDRED_D18;
        uint256 redeemTimestamp = block.timestamp;

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(FraxBPPHOMetapoolNotSet.selector));
        fraxBPInitModule.redeem();
    }

    // Basic redeem
    function testRedeemFull() public {
        uint256 depositAmount = ONE_HUNDRED_D18;
        uint256 expectedMint = depositAmount;
        _testDepositAnyModule(depositAmount, expectedMint, fraxBPInitModule, block.timestamp);

        // Add liquidity to FraxBP pool
        _testAddFraxBPLiquidity(ONE_HUNDRED_D6, ONE_HUNDRED_D18);

        // Add liquidity to FraxBP / PHO pool
        _testAddFraxBPPHOLiquidity();

        uint256 redeemAmount = ONE_HUNDRED_D18;
        uint256 redeemTimestamp = block.timestamp;

        vm.prank(owner);
        fraxBPInitModule.setFraxBpPHOPool(address(fraxBPPHOMetapool));

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
