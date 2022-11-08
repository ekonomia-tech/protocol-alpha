// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../BaseSetup.t.sol";
import "@modules/cdpModule/CDPPool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@oracle/IPriceOracle.sol";
import "@oracle/DummyOracle.sol";

contract CDP_stETHTest is BaseSetup {
    struct PoolBalances {
        uint256 debt;
        uint256 collateral;
        uint256 feesCollected;
        uint256 pho;
        uint256 collToken;
    }

    struct UserBalance {
        uint256 debt;
        uint256 collateral;
        uint256 pho;
        uint256 collToken;
        uint256 cr;
    }

    struct Balances {
        UserBalance user;
        PoolBalances pool;
    }

    error ZeroAddress();
    error ZeroValue();
    error ValueNotInRange();
    error DebtTooLow();
    error CRTooLow();
    error CDPNotActive();
    error CDPAlreadyActive();
    error FullAmountNotPresent();
    error NotInLiquidationZone();
    error MinDebtNotMet();

    event Opened(address indexed user, uint256 debt, uint256 collateral);
    event CollateralAdded(address indexed user, uint256 addedCollateral, uint256 collateral);
    event CollateralRemoved(
        address indexed user, uint256 removedCollateral, uint256 collateralLeft
    );
    event DebtAdded(address indexed user, uint256 addedDebt, uint256 debt);
    event DebtRemoved(address indexed user, uint256 removedDebt, uint256 debt);
    event Closed(address indexed user);
    event Liquidated(
        address indexed user,
        address indexed liquidator,
        uint256 paidToLiquidator,
        uint256 debt,
        uint256 collateralLiquidated,
        uint256 repaidToDebtor
    );
    event WithdrawFees(uint256 amountWithdrawn);

    uint256 public constant MIN_CR = 170 * 10 ** 3;
    uint256 public constant LIQUIDATION_CR = 150 * 10 ** 3;
    uint256 public constant MIN_DEBT = ONE_THOUSAND_D18;
    uint256 public constant PROTOCOL_FEE = 5 * 10 ** 2;
    uint256 public constant LIQUIDATION_REWARD = 5 * 10 ** 3;
    uint256 public constant MINTING_CEILING = POOL_CEILING;
    uint256 public constant MAX_PPH = 10 ** 5;

    CDPPool public cdpPool;
    IStETH public stETH = IStETH(STETH_ADDRESS);

    IStETH public collToken;

    function setUp() public {
        cdpPool = new CDPPool(
            address(moduleManager),
            address(priceOracle),
            STETH_ADDRESS,
            MIN_CR,
            LIQUIDATION_CR,
            MIN_DEBT,
            PROTOCOL_FEE
        );

        collToken = IStETH(STETH_ADDRESS);

        vm.prank(PHOGovernance);
        moduleManager.addModule(address(cdpPool));

        vm.prank(TONGovernance);
        moduleManager.setPHOCeilingForModule(address(cdpPool), MINTING_CEILING);

        vm.warp(block.timestamp + moduleManager.moduleDelay());
        moduleManager.executeCeilingUpdate(address(cdpPool));

        /// user1 is a normal user
        vm.deal(user1, 10000 * 10 ** 18);
        vm.startPrank(user1);

        collToken.submit{value: (user1.balance)}(owner);
        collToken.approve(address(cdpPool), type(uint256).max);

        pho.approve(address(kernel), type(uint256).max);
        vm.stopPrank();

        /// user 2 is a liquidator
        vm.prank(address(moduleManager));
        kernel.mintPHO(user2, 10 * ONE_MILLION_D18);

        vm.prank(user2);
        pho.approve(address(kernel), type(uint256).max);
    }

    /// open()

    function testOpen() public {
        uint256 collateralAmount = 2 * ONE_D18;
        uint256 debtAmount = ONE_THOUSAND_D18;

        uint256 userCollTokenBalanceBefore = collToken.balanceOf(user1);
        (uint256 debtBalanceBefore, uint256 collateralBalanceBefore) = cdpPool.pool();

        vm.expectEmit(true, false, false, true);
        emit Opened(user1, debtAmount, collateralAmount);
        vm.prank(user1);
        cdpPool.open(collateralAmount, debtAmount);

        uint256 userCollTokenBalanceAfter = collToken.balanceOf(user1);
        (uint256 debtBalanceAfter, uint256 collateralBalanceAfter) = cdpPool.pool();
        (uint256 userPositionDebt, uint256 userPositionCollateral) = cdpPool.cdps(user1);

        assertEq(collateralBalanceBefore + collateralAmount, collateralBalanceAfter);
        assertEq(debtBalanceBefore + debtAmount, debtBalanceAfter);
        assertEq(userPositionDebt, debtAmount);
        assertEq(userPositionCollateral, collateralAmount);
        assertApproxEqAbs(collToken.balanceOf(address(cdpPool)), collateralAmount, 1 wei);
        assertApproxEqAbs(
            userCollTokenBalanceBefore, userCollTokenBalanceAfter + collateralAmount, 1 wei
        );
        assertEq(pho.balanceOf(address(user1)), debtAmount);
    }

    function testCannotOpenZeroAmount() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroValue.selector));
        vm.prank(user1);
        cdpPool.open(0, ONE_THOUSAND_D18);

        vm.expectRevert(abi.encodeWithSelector(ZeroValue.selector));
        vm.prank(user1);
        cdpPool.open(ONE_THOUSAND_D18, 0);
    }

    function testCannotOpenDebtLowerThanMinDebt(uint256 debtAmount) public {
        debtAmount = bound(debtAmount, 1, 999);
        vm.expectRevert(abi.encodeWithSelector(DebtTooLow.selector));
        vm.prank(user1);
        cdpPool.open(ONE_D18, debtAmount);
    }

    function testCannotOpenAlreadyActive() public {
        _openHealthyPosition(user1, ONE_THOUSAND_D18, 200);
        vm.expectRevert(abi.encodeWithSelector(CDPAlreadyActive.selector));
        vm.prank(user1);
        cdpPool.open(2 * ONE_D18, ONE_THOUSAND_D18);
    }

    /// openFor()

    function testOpenFor() public {
        uint256 collateralAmount = 2 * ONE_D18;
        uint256 debtAmount = ONE_THOUSAND_D18;

        uint256 userCollTokenBalanceBefore = collToken.balanceOf(user1);
        (uint256 debtBalanceBefore, uint256 collateralBalanceBefore) = cdpPool.pool();

        vm.expectEmit(true, false, false, true);
        emit Opened(user1, debtAmount, collateralAmount);
        vm.prank(owner);
        cdpPool.openFor(user1, collateralAmount, debtAmount);

        uint256 userCollTokenBalanceAfter = collToken.balanceOf(user1);
        (uint256 debtBalanceAfter, uint256 collateralBalanceAfter) = cdpPool.pool();
        (uint256 userPositionDebt, uint256 userPositionCollateral) = cdpPool.cdps(user1);

        assertEq(collateralBalanceBefore + collateralAmount, collateralBalanceAfter);
        assertEq(debtBalanceBefore + debtAmount, debtBalanceAfter);
        assertEq(userPositionDebt, debtAmount);
        assertEq(userPositionCollateral, collateralAmount);
        assertApproxEqAbs(collToken.balanceOf(address(cdpPool)), collateralAmount, 1 wei);
        assertApproxEqAbs(
            userCollTokenBalanceBefore, userCollTokenBalanceAfter + collateralAmount, 1 wei
        );
        assertEq(pho.balanceOf(address(user1)), debtAmount);
    }

    function testCannotOpenForZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroAddress.selector));
        vm.prank(owner);
        cdpPool.openFor(address(0), ONE_D18, ONE_THOUSAND_D18);
    }

    /// test settings:
    /// collateral - 1 eth
    /// debt - 1 eth worth of $PHO
    /// CR - 100%
    function testCannotOpenCRTooLow(uint256 collAmount) public {
        uint256 debtAmount = ONE_THOUSAND_D18;
        uint256 debtInCollateral = cdpPool.debtToCollateral(debtAmount);
        collAmount = bound(collAmount, debtInCollateral, (debtInCollateral * MIN_CR / MAX_PPH) - 1);

        vm.expectRevert(abi.encodeWithSelector(CRTooLow.selector));
        vm.prank(user1);
        cdpPool.open(collAmount, debtAmount);
    }

    /// addCollateral()

    function testAddCollateral() public {
        uint256 collAddition = ONE_D18;
        _openHealthyPosition(user1, ONE_THOUSAND_D18, 200);

        Balances memory _before = _getBalances(user1);
        uint256 expectedCR =
            cdpPool.computeCR(_before.user.collateral + collAddition, _before.user.debt);
        uint256 expectedNewCollateral = _before.user.collateral + collAddition;

        vm.expectEmit(true, false, false, true);
        emit CollateralAdded(user1, collAddition, expectedNewCollateral);
        vm.prank(user1);
        cdpPool.addCollateral(collAddition);

        Balances memory _after = _getBalances(user1);

        assertEq(_after.user.debt, _before.user.debt);
        assertApproxEqAbs(_after.user.collateral, _before.user.collateral + collAddition, 1 wei);
        assertApproxEqAbs(_after.user.collToken, _before.user.collToken - collAddition, 1 wei);
        assertEq(_after.user.pho, _before.user.pho);
        assertEq(_after.pool.debt, _before.pool.debt);
        assertApproxEqAbs(_after.pool.collateral, _before.pool.collateral + collAddition, 1 wei);
        assertEq(_after.user.cr, expectedCR);
    }

    function testCannotAddCollateralZeroValue() public {
        _openHealthyPosition(user1, ONE_THOUSAND_D18, 200);
        vm.expectRevert(abi.encodeWithSelector(ZeroValue.selector));
        vm.prank(user1);
        cdpPool.addCollateral(0);
    }

    function testCannotAddCollateralCDPNotActive() public {
        vm.expectRevert(abi.encodeWithSelector(CDPNotActive.selector));
        vm.prank(user1);
        cdpPool.addCollateral(ONE_D18);
    }

    /// addCollateralFor()

    function testAddCollateralFor() public {
        uint256 collAddition = ONE_D18;
        _openHealthyPosition(user1, ONE_THOUSAND_D18, 200);

        Balances memory _before = _getBalances(user1);
        uint256 expectedCR =
            cdpPool.computeCR(_before.user.collateral + collAddition, _before.user.debt);
        uint256 expectedNewCollateral = _before.user.collateral + collAddition;

        vm.expectEmit(true, false, false, true);
        emit CollateralAdded(user1, collAddition, expectedNewCollateral);
        vm.prank(owner);
        cdpPool.addCollateralFor(user1, collAddition);

        Balances memory _after = _getBalances(user1);

        assertEq(_after.user.debt, _before.user.debt);
        assertApproxEqAbs(_after.user.collateral, _before.user.collateral + collAddition, 1 wei);
        assertApproxEqAbs(_after.user.collToken, _before.user.collToken - collAddition, 1 wei);
        assertEq(_after.user.pho, _before.user.pho);
        assertEq(_after.pool.debt, _before.pool.debt);
        assertApproxEqAbs(_after.pool.collateral, _before.pool.collateral + collAddition, 1 wei);
        assertEq(_after.user.cr, expectedCR);
    }

    function testCannotAddCollateralFoZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroAddress.selector));
        vm.prank(owner);
        cdpPool.addCollateralFor(address(0), ONE_D18);
    }

    /// removeCollateral()

    function testRemoveCollateral() public {
        uint256 collReduction = ONE_D18;
        _openHealthyPosition(user1, ONE_THOUSAND_D18, 400);

        Balances memory _before = _getBalances(user1);

        uint256 expectedNewCollateral = _before.user.collateral - collReduction;
        uint256 expectedCR =
            cdpPool.computeCR(_before.user.collateral - collReduction, _before.user.debt);

        vm.expectEmit(true, false, false, true);
        emit CollateralRemoved(user1, collReduction, expectedNewCollateral);
        vm.prank(user1);
        cdpPool.removeCollateral(collReduction);

        Balances memory _after = _getBalances(user1);

        assertEq(_after.user.debt, _before.user.debt);
        assertEq(_after.user.collateral, _before.user.collateral - collReduction);
        assertApproxEqAbs(_after.user.collToken, _before.user.collToken + collReduction, 1 wei);
        assertEq(_after.user.pho, _before.user.pho);
        assertEq(_after.pool.debt, _before.pool.debt);
        assertApproxEqAbs(_after.pool.collateral, _before.pool.collateral - collReduction, 1 wei);
        assertEq(_after.user.cr, expectedCR);
    }

    function testCannotRemoveCollateralZeroValue() public {
        _openHealthyPosition(user1, ONE_THOUSAND_D18, 200);
        vm.expectRevert(abi.encodeWithSelector(ZeroValue.selector));
        vm.prank(user1);
        cdpPool.removeCollateral(0);
    }

    function testCannotRemoveCollateralCDPNotActive() public {
        vm.expectRevert(abi.encodeWithSelector(CDPNotActive.selector));
        vm.prank(user1);
        cdpPool.removeCollateral(ONE_D18);
    }

    function testCannotRemoveCollateralAmountTooHigh() public {
        _openHealthyPosition(user1, ONE_THOUSAND_D18, 175);
        // calculate the reduction from 175% to 165%
        (, uint256 collAmountInCR175) = cdpPool.cdps(user1);
        uint256 collAmountInCR165 = cdpPool.debtToCollateral(ONE_THOUSAND_D18) * 165000 / MAX_PPH;
        uint256 collReduction = collAmountInCR175 - collAmountInCR165;

        vm.expectRevert(abi.encodeWithSelector(CRTooLow.selector));
        vm.prank(user1);
        cdpPool.removeCollateral(collReduction);
    }

    /// removeCollateralFor()

    function testRemoveCollateralFor() public {
        uint256 collReduction = ONE_D18;
        _openHealthyPosition(user1, ONE_THOUSAND_D18, 400);

        Balances memory _before = _getBalances(user1);

        uint256 expectedNewCollateral = _before.user.collateral - collReduction;
        uint256 expectedCR =
            cdpPool.computeCR(_before.user.collateral - collReduction, _before.user.debt);

        vm.expectEmit(true, false, false, true);
        emit CollateralRemoved(user1, collReduction, expectedNewCollateral);
        vm.prank(owner);
        cdpPool.removeCollateralFor(user1, collReduction);

        Balances memory _after = _getBalances(user1);

        assertEq(_after.user.debt, _before.user.debt);
        assertEq(_after.user.collateral, _before.user.collateral - collReduction);
        assertApproxEqAbs(_after.user.collToken, _before.user.collToken + collReduction, 1 wei);
        assertEq(_after.user.pho, _before.user.pho);
        assertEq(_after.pool.debt, _before.pool.debt);
        assertApproxEqAbs(_after.pool.collateral, _before.pool.collateral - collReduction, 1 wei);
        assertEq(_after.user.cr, expectedCR);
    }

    function testCannotRemoveCollateralFoZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroAddress.selector));
        vm.prank(owner);
        cdpPool.removeCollateralFor(address(0), ONE_D18);
    }

    /// addDebt()

    function testAddDebt() public {
        uint256 debtAddition = ONE_THOUSAND_D18;
        _openHealthyPosition(user1, ONE_THOUSAND_D18, 400);

        Balances memory _before = _getBalances(user1);

        uint256 expectedDebt = _before.user.debt + debtAddition;
        uint256 expectedCR =
            cdpPool.computeCR(_before.user.collateral, _before.user.debt + debtAddition);

        vm.expectEmit(true, false, false, true);
        emit DebtAdded(user1, debtAddition, expectedDebt);
        vm.prank(user1);
        cdpPool.addDebt(debtAddition);

        Balances memory _after = _getBalances(user1);

        assertEq(_after.user.debt, _before.user.debt + debtAddition);
        assertEq(_after.user.collateral, _before.user.collateral);
        assertEq(_after.user.collToken, _before.user.collToken);
        assertEq(_after.user.pho, _before.user.pho + debtAddition);
        assertEq(_after.pool.debt, _before.pool.debt + debtAddition);
        assertEq(_after.pool.collateral, _before.pool.collateral);
        assertEq(_after.user.cr, expectedCR);
    }

    function testCannotAddDebtZeroValue() public {
        _openHealthyPosition(user1, ONE_THOUSAND_D18, 200);
        vm.expectRevert(abi.encodeWithSelector(ZeroValue.selector));
        vm.prank(user1);
        cdpPool.addDebt(0);
    }

    function testCannotAddDebtCDPNotActive() public {
        vm.expectRevert(abi.encodeWithSelector(CDPNotActive.selector));
        vm.prank(user1);
        cdpPool.addDebt(ONE_D18);
    }

    function testCannotAddDebtAmountTooHigh() public {
        _openHealthyPosition(user1, ONE_THOUSAND_D18, 175);
        // calculate the reduction from 175% to 165%
        uint256 debtAddition = ONE_THOUSAND_D18;

        vm.expectRevert(abi.encodeWithSelector(CRTooLow.selector));
        vm.prank(user1);
        cdpPool.addDebt(debtAddition);
    }

    /// removeDebt()

    function testRemoveDebt() public {
        uint256 debtReduction = ONE_THOUSAND_D18;
        _openHealthyPosition(user1, 3 * ONE_THOUSAND_D18, 175);

        Balances memory _before = _getBalances(user1);
        uint256 protocolFee = cdpPool.debtToCollateral(debtReduction * PROTOCOL_FEE / MAX_PPH);
        uint256 expectedCR = cdpPool.computeCR(
            _before.user.collateral - protocolFee, _before.user.debt - debtReduction
        );
        uint256 expectedNewDebt = _before.user.debt - debtReduction;

        vm.expectEmit(true, false, false, true);
        emit DebtRemoved(user1, debtReduction, expectedNewDebt);
        vm.prank(user1);
        cdpPool.removeDebt(debtReduction);

        Balances memory _after = _getBalances(user1);

        assertEq(_after.user.debt, _before.user.debt - debtReduction);
        assertEq(_after.user.collateral, _before.user.collateral - protocolFee);
        assertEq(_after.user.collToken, _before.user.collToken);
        assertEq(_after.user.pho, _before.user.pho - debtReduction);
        assertEq(_after.pool.debt, _before.pool.debt - debtReduction);
        assertEq(_after.pool.collateral, _before.pool.collateral - protocolFee);
        assertEq(_after.pool.feesCollected, _before.pool.feesCollected + protocolFee);
        assertEq(_after.user.cr, expectedCR);
    }

    function testCannotRemoveDebtZeroValue() public {
        _openHealthyPosition(user1, ONE_THOUSAND_D18, 200);
        vm.expectRevert(abi.encodeWithSelector(ZeroValue.selector));
        vm.prank(user1);
        cdpPool.removeDebt(0);
    }

    function testCannotRemoveDebtCDPNotActive() public {
        vm.expectRevert(abi.encodeWithSelector(CDPNotActive.selector));
        vm.prank(user1);
        cdpPool.removeDebt(ONE_D18);
    }

    function testCannotRemoveDebtAmountTooHigh(uint256 debtReduction) public {
        _openHealthyPosition(user1, ONE_THOUSAND_D18, 175);
        debtReduction = bound(debtReduction, ONE_D18, ONE_THOUSAND_D18);

        vm.expectRevert(abi.encodeWithSelector(MinDebtNotMet.selector));
        vm.prank(user1);
        cdpPool.removeDebt(debtReduction);
    }

    /// close()

    function testClose() public {
        _openHealthyPosition(user1, ONE_THOUSAND_D18, 175);

        Balances memory _before = _getBalances(user1);
        uint256 protocolFee = cdpPool.debtToCollateral(_before.user.debt * PROTOCOL_FEE / MAX_PPH);
        uint256 expectedCollateralBack = _before.user.collateral - protocolFee;

        vm.expectEmit(true, false, false, true);
        emit Closed(user1);
        vm.prank(user1);
        cdpPool.close();

        Balances memory _after = _getBalances(user1);

        assertEq(_after.user.debt, 0);
        assertEq(_after.user.collateral, 0);
        assertApproxEqAbs(
            _after.user.collToken, _before.user.collToken + expectedCollateralBack, 1 wei
        );
        assertEq(_after.user.pho, _before.user.pho - _before.user.debt);
        assertEq(_after.pool.debt, _before.pool.debt - _before.user.debt);
        assertApproxEqAbs(
            _after.pool.collateral, _before.pool.collateral - _before.user.collateral, 1 wei
        );
        assertEq(_after.pool.feesCollected, _before.pool.feesCollected + protocolFee);
        assertApproxEqAbs(
            _after.pool.collToken,
            _before.pool.collToken + protocolFee - _before.user.collateral,
            1 wei
        );
    }

    function testCannotCloseCDPNotActive() public {
        vm.expectRevert(abi.encodeWithSelector(CDPNotActive.selector));
        vm.prank(user1);
        cdpPool.close();
    }

    /// liquidate()

    function testLiquidate() public {
        uint256 debtAmount = ONE_THOUSAND_D18;
        priceOracle.setWethUSDPrice(1500 * 10 ** 18);
        _openHealthyPosition(user1, debtAmount, 175);

        Balances memory _before = _getBalances(user1);
        UserBalance memory _liquidatorBefore = _getUserBalance(user2);

        priceOracle.setWethUSDPrice(1100 * 10 ** 18);

        uint256 protocolFee = _before.user.collateral * PROTOCOL_FEE / MAX_PPH;
        uint256 liquidationReward =
            (_before.user.collateral - protocolFee) * LIQUIDATION_REWARD / MAX_PPH;
        uint256 expectedLiquidatorAmount =
            cdpPool.debtToCollateral(_before.user.debt) + liquidationReward;
        uint256 expectedCollateralBackToOwner =
            _before.user.collateral - protocolFee - expectedLiquidatorAmount;

        vm.expectEmit(true, true, false, true);
        emit Liquidated(
            user1,
            user2,
            expectedLiquidatorAmount,
            _before.user.debt,
            _before.user.collateral,
            expectedCollateralBackToOwner
            );
        vm.expectEmit(true, false, false, true);
        emit Closed(user1);
        vm.prank(user2);
        cdpPool.liquidate(user1);

        Balances memory _after = _getBalances(user1);
        UserBalance memory _liquidatorAfter = _getUserBalance(user2);

        assertEq(_after.user.collateral, 0);
        assertEq(_after.user.debt, 0);
        assertApproxEqAbs(
            _after.user.collToken, _before.user.collToken + expectedCollateralBackToOwner, 2 wei
        );
        assertEq(_after.user.pho, _before.user.pho);
        assertApproxEqAbs(
            _liquidatorAfter.collToken,
            _liquidatorBefore.collToken + expectedLiquidatorAmount,
            2 wei
        );
        assertEq(_liquidatorAfter.pho, _liquidatorBefore.pho - debtAmount);
        assertApproxEqAbs(
            _after.pool.collToken,
            _before.pool.collToken + protocolFee - _before.user.collateral,
            2 wei
        );
        assertApproxEqAbs(
            _after.pool.collateral, _before.pool.collateral - _before.user.collateral, 2 wei
        );
        assertEq(_after.pool.debt, _before.pool.debt - debtAmount);
        assertEq(_after.pool.feesCollected, _before.pool.feesCollected + protocolFee);
    }

    function testCannotLiquidateCDPNotActive() public {
        vm.expectRevert(abi.encodeWithSelector(CDPNotActive.selector));
        vm.prank(user2);
        cdpPool.liquidate(user1);
    }

    function testCannotLiquidateNotInLiquidationZone() public {
        _openHealthyPosition(user1, ONE_THOUSAND_D18, 175);
        vm.expectRevert(abi.encodeWithSelector(NotInLiquidationZone.selector));
        vm.prank(user2);
        cdpPool.liquidate(user1);
    }

    /// computeCR()

    function testComputeCR() public {
        uint256 debtAmount = ONE_THOUSAND_D18;
        uint256 collateralAmount = 2 * ONE_D18;
        uint256 collateralInUSD =
            priceOracle.getPrice(address(collToken)) * collateralAmount / 10 ** 18;
        uint256 expectedCR = collateralInUSD * MAX_PPH / debtAmount;

        assertEq(expectedCR, cdpPool.computeCR(collateralAmount, debtAmount));
    }

    /// calculateProtocolFee()

    function testCalculateProtocolFee(uint256 collateralAmount) public {
        collateralAmount = bound(collateralAmount, ONE_D18, ONE_THOUSAND_D18);
        uint256 expectedFee = collateralAmount * PROTOCOL_FEE / MAX_PPH;
        (uint256 actualFee, uint256 remainder) = cdpPool.calculateProtocolFee(collateralAmount);
        assertEq(actualFee, expectedFee);
        assertEq(remainder, collateralAmount - expectedFee);
    }

    /// calculateLiquidationFee()

    function testCalculateLiquidationFee(uint256 collateralAmount) public {
        collateralAmount = bound(collateralAmount, ONE_D18, ONE_THOUSAND_D18);
        uint256 expectedFee = collateralAmount * LIQUIDATION_REWARD / MAX_PPH;
        uint256 actualFee = cdpPool.calculateLiquidationFee(collateralAmount);
        assertEq(actualFee, expectedFee);
    }

    /// debtToCollateral()

    function testDebtToCollateral(uint256 debt) public {
        debt = bound(debt, ONE_THOUSAND_D18, ONE_MILLION_D18);
        uint256 collateralPrice = priceOracle.getPrice(address(collToken));
        uint256 expectedCollateral = debt * 10 ** 18 / collateralPrice;
        assertEq(cdpPool.debtToCollateral(debt), expectedCollateral);
    }

    /// collateralToUSD

    function testCollateralToUSD(uint256 collateralAmount) public {
        collateralAmount = bound(collateralAmount, ONE_D18, ONE_THOUSAND_D18);
        uint256 collateralPrice = priceOracle.getPrice(address(collToken));
        uint256 expected = collateralAmount * collateralPrice / 10 ** 18;
        assertEq(cdpPool.collateralToUSD(collateralAmount), expected);
    }

    /// private functions

    /// @notice opens a position for a user with certain debt and specific CR
    /// @param user the user that opens the position
    /// @param debtAmount the amount of debt to take
    /// @param cr that wanted CR in 3 digits - e.g. 200 = 200%
    function _openHealthyPosition(address user, uint256 debtAmount, uint256 cr)
        private
        returns (uint256, uint256)
    {
        require(cr >= (MIN_CR / 10 ** 3) && debtAmount >= MIN_DEBT);
        uint256 collateralAmount = cdpPool.debtToCollateral(debtAmount * (cr * 10 ** 3) / MAX_PPH);
        vm.prank(user);
        cdpPool.open(collateralAmount, debtAmount);
    }

    function _getPoolBalances() private returns (PoolBalances memory) {
        PoolBalances memory balance;
        (uint256 debt, uint256 collateral) = cdpPool.pool();
        balance.debt = debt;
        balance.collateral = collateral;
        balance.feesCollected = cdpPool.feesCollected();
        balance.pho = pho.balanceOf(address(cdpPool));
        balance.collToken = collToken.balanceOf(address(cdpPool));
        return balance;
    }

    function _getUserBalance(address user) private returns (UserBalance memory) {
        UserBalance memory balance;
        (uint256 debt, uint256 collateral) = cdpPool.cdps(user);
        balance.debt = debt;
        balance.collateral = collateral;
        balance.pho = pho.balanceOf(user);
        balance.collToken = collToken.balanceOf(user);
        if (balance.collateral != 0 && balance.debt != 0) {
            balance.cr = cdpPool.computeCR(balance.collateral, balance.debt);
        }
        return balance;
    }

    function _getBalances(address user) private returns (Balances memory) {
        Balances memory balance;
        balance.user = _getUserBalance(user);
        balance.pool = _getPoolBalances();
        return balance;
    }
}

interface IStETH is IERC20 {
    function submit(address _referral) external payable;
}
