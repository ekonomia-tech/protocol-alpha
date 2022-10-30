// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../BaseSetup.t.sol";
import "@modules/cdpModule/CDPPool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@oracle/IPriceOracle.sol";
import "@oracle/DummyOracle.sol";

contract CDPPoolTest is BaseSetup {
    struct PoolBalance {
        uint256 debt;
        uint256 collateral;
        uint256 earnedFees;
        uint256 pho;
        uint256 weth;
    }

    struct UserBalance {
        uint256 debt;
        uint256 collateral;
        uint256 pho;
        uint256 weth;
        uint256 cr;
    }

    struct Balances {
        UserBalance user;
        PoolBalance pool;
    }

    error ZeroAddress();
    error ZeroValue();
    error ValueNotInRange();
    error DebtTooLow();
    error CRTooLow();
    error CDPNotActive();
    error CDPAlreadyActive();
    error RequestedAmountTooHigh();
    error FullAmountNotPresent();
    error NotInLiquidationZone();

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
    uint256 public constant POINT_PRECISION = 10 ** 5;

    CDPPool public wethPool;
    IWETH public weth = IWETH(WETH_ADDRESS);

    function setUp() public {
        wethPool = new CDPPool(
            address(moduleManager),
            address(priceOracle),
            WETH_ADDRESS,
            MIN_CR,
            LIQUIDATION_CR,
            MIN_DEBT,
            PROTOCOL_FEE
        );

        vm.prank(PHOGovernance);
        moduleManager.addModule(address(wethPool));

        vm.prank(TONGovernance);
        moduleManager.setPHOCeilingForModule(address(wethPool), MINTING_CEILING);

        /// user1 is a normal user
        vm.deal(user1, 10000 * 10 ** 18);
        vm.startPrank(user1);
        weth.deposit{value: (user1.balance)}();
        weth.approve(address(wethPool), type(uint256).max);
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

        uint256 userWethBalanceBefore = weth.balanceOf(user1);
        (uint256 debtBalanceBefore, uint256 collateralBalanceBefore) = wethPool.balance();

        vm.expectEmit(true, false, false, true);
        emit Opened(user1, debtAmount, collateralAmount);
        vm.prank(user1);
        wethPool.open(collateralAmount, debtAmount);

        uint256 userWethBalanceAfter = weth.balanceOf(user1);
        (uint256 debtBalanceAfter, uint256 collateralBalanceAfter) = wethPool.balance();
        (uint256 userPositionDebt, uint256 userPositionCollateral) = wethPool.cdps(user1);

        assertEq(collateralBalanceBefore + collateralAmount, collateralBalanceAfter);
        assertEq(debtBalanceBefore + debtAmount, debtBalanceAfter);
        assertEq(userPositionDebt, debtAmount);
        assertEq(userPositionCollateral, collateralAmount);
        assertEq(weth.balanceOf(address(wethPool)), collateralAmount);
        assertEq(userWethBalanceBefore, userWethBalanceAfter + collateralAmount);
        assertEq(pho.balanceOf(address(user1)), debtAmount);
    }

    function testCannotOpenZeroAmount() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroValue.selector));
        vm.prank(user1);
        wethPool.open(0, ONE_THOUSAND_D18);

        vm.expectRevert(abi.encodeWithSelector(ZeroValue.selector));
        vm.prank(user1);
        wethPool.open(ONE_THOUSAND_D18, 0);
    }

    function testCannotOpenDebtLowerThanMinDebt(uint256 debtAmount) public {
        debtAmount = bound(debtAmount, 1, 999);
        vm.expectRevert(abi.encodeWithSelector(DebtTooLow.selector));
        vm.prank(user1);
        wethPool.open(ONE_D18, debtAmount);
    }

    function testCannotOpenAlreadyActive() public {
        _openHealthyPosition(user1, ONE_THOUSAND_D18, 200);
        vm.expectRevert(abi.encodeWithSelector(CDPAlreadyActive.selector));
        vm.prank(user1);
        wethPool.open(2 * ONE_D18, ONE_THOUSAND_D18);
    }

    /// test settings:
    /// collateral - 1 eth
    /// debt - 1 eth worth of $PHO
    /// CR - 100%
    function testCannotOpenCRTooLow(uint256 collAmount) public {
        uint256 debtAmount = ONE_THOUSAND_D18;
        uint256 debtInCollateral = wethPool.debtToCollateral(debtAmount);
        collAmount =
            bound(collAmount, debtInCollateral, (debtInCollateral * MIN_CR / POINT_PRECISION) - 1);

        vm.expectRevert(abi.encodeWithSelector(CRTooLow.selector));
        vm.prank(user1);
        wethPool.open(collAmount, debtAmount);
    }

    /// addCollateral()

    function testAddCollateral() public {
        uint256 collAddition = ONE_D18;
        _openHealthyPosition(user1, ONE_THOUSAND_D18, 200);

        Balances memory _before = _getBalances(user1);
        uint256 expectedCR =
            wethPool.computeCR(_before.user.collateral + collAddition, _before.user.debt);
        uint256 expectedNewCollateral = _before.user.collateral + collAddition;

        vm.expectEmit(true, false, false, true);
        emit CollateralAdded(user1, collAddition, expectedNewCollateral);
        vm.prank(user1);
        wethPool.addCollateral(collAddition);

        Balances memory _after = _getBalances(user1);

        assertEq(_after.user.debt, _before.user.debt);
        assertEq(_after.user.collateral, _before.user.collateral + collAddition);
        assertEq(_after.user.weth, _before.user.weth - collAddition);
        assertEq(_after.user.pho, _before.user.pho);
        assertEq(_after.pool.debt, _before.pool.debt);
        assertEq(_after.pool.collateral, _before.pool.collateral + collAddition);
        assertEq(_after.user.cr, expectedCR);
    }

    function testCannotAddCollateralZeroValue() public {
        _openHealthyPosition(user1, ONE_THOUSAND_D18, 200);
        vm.expectRevert(abi.encodeWithSelector(ZeroValue.selector));
        vm.prank(user1);
        wethPool.addCollateral(0);
    }

    function testCannotAddCollateralCDPNotActive() public {
        vm.expectRevert(abi.encodeWithSelector(CDPNotActive.selector));
        vm.prank(user1);
        wethPool.addCollateral(ONE_D18);
    }

    /// removeCollateral()

    function testRemoveCollateral() public {
        uint256 collReduction = ONE_D18;
        _openHealthyPosition(user1, ONE_THOUSAND_D18, 400);

        Balances memory _before = _getBalances(user1);

        uint256 protocolFee = collReduction * PROTOCOL_FEE / POINT_PRECISION;
        uint256 expectedNewCollateral = _before.user.collateral - collReduction;
        uint256 expectedCR =
            wethPool.computeCR(_before.user.collateral - collReduction, _before.user.debt);

        vm.expectEmit(true, false, false, true);
        emit CollateralRemoved(user1, collReduction, expectedNewCollateral);
        vm.prank(user1);
        wethPool.removeCollateral(collReduction);

        Balances memory _after = _getBalances(user1);

        assertEq(_after.user.debt, _before.user.debt);
        assertEq(_after.user.collateral, _before.user.collateral - collReduction);
        assertEq(_after.user.weth, _before.user.weth + (collReduction - protocolFee));
        assertEq(_after.user.pho, _before.user.pho);
        assertEq(_after.pool.debt, _before.pool.debt);
        assertEq(_after.pool.collateral, _before.pool.collateral - collReduction);
        assertEq(_after.pool.earnedFees, _before.pool.earnedFees + protocolFee);
        assertEq(weth.balanceOf(address(wethPool)), _after.pool.collateral + _after.pool.earnedFees);
        assertEq(_after.user.cr, expectedCR);
    }

    function testCannotRemoveCollateralZeroValue() public {
        _openHealthyPosition(user1, ONE_THOUSAND_D18, 200);
        vm.expectRevert(abi.encodeWithSelector(ZeroValue.selector));
        vm.prank(user1);
        wethPool.removeCollateral(0);
    }

    function testCannotRemoveCollateralCDPNotActive() public {
        vm.expectRevert(abi.encodeWithSelector(CDPNotActive.selector));
        vm.prank(user1);
        wethPool.removeCollateral(ONE_D18);
    }

    function testCannotRemoveCollateralAmountTooHigh() public {
        _openHealthyPosition(user1, ONE_THOUSAND_D18, 175);
        // calculate the reduction from 175% to 165%
        (, uint256 collAmountInCR175) = wethPool.cdps(user1);
        uint256 collAmountInCR165 =
            wethPool.debtToCollateral(ONE_THOUSAND_D18) * 165000 / POINT_PRECISION;
        uint256 collReduction = collAmountInCR175 - collAmountInCR165;

        vm.expectRevert(abi.encodeWithSelector(RequestedAmountTooHigh.selector));
        vm.prank(user1);
        wethPool.removeCollateral(collReduction);
    }

    /// addDebt()

    function testAddDebt() public {
        uint256 debtAddition = ONE_THOUSAND_D18;
        _openHealthyPosition(user1, ONE_THOUSAND_D18, 400);

        Balances memory _before = _getBalances(user1);

        uint256 expectedDebt = _before.user.debt + debtAddition;
        uint256 expectedCR =
            wethPool.computeCR(_before.user.collateral, _before.user.debt + debtAddition);

        vm.expectEmit(true, false, false, true);
        emit DebtAdded(user1, debtAddition, expectedDebt);
        vm.prank(user1);
        wethPool.addDebt(debtAddition);

        Balances memory _after = _getBalances(user1);

        assertEq(_after.user.debt, _before.user.debt + debtAddition);
        assertEq(_after.user.collateral, _before.user.collateral);
        assertEq(_after.user.weth, _before.user.weth);
        assertEq(_after.user.pho, _before.user.pho + debtAddition);
        assertEq(_after.pool.debt, _before.pool.debt + debtAddition);
        assertEq(_after.pool.collateral, _before.pool.collateral);
        assertEq(_after.user.cr, expectedCR);
    }

    function testCannotAddDebtZeroValue() public {
        _openHealthyPosition(user1, ONE_THOUSAND_D18, 200);
        vm.expectRevert(abi.encodeWithSelector(ZeroValue.selector));
        vm.prank(user1);
        wethPool.addDebt(0);
    }

    function testCannotAddDebtCDPNotActive() public {
        vm.expectRevert(abi.encodeWithSelector(CDPNotActive.selector));
        vm.prank(user1);
        wethPool.addDebt(ONE_D18);
    }

    function testCannotAddDebtAmountTooHigh() public {
        _openHealthyPosition(user1, ONE_THOUSAND_D18, 175);
        // calculate the reduction from 175% to 165%
        uint256 debtAddition = ONE_THOUSAND_D18;

        vm.expectRevert(abi.encodeWithSelector(RequestedAmountTooHigh.selector));
        vm.prank(user1);
        wethPool.addDebt(debtAddition);
    }

    /// removeDebt()

    function testRemoveDebt() public {
        uint256 debtReduction = ONE_THOUSAND_D18;
        _openHealthyPosition(user1, 3 * ONE_THOUSAND_D18, 175);

        Balances memory _before = _getBalances(user1);
        uint256 expectedCR =
            wethPool.computeCR(_before.user.collateral, _before.user.debt - debtReduction);
        uint256 expectedNewDebt = _before.user.debt - debtReduction;

        vm.expectEmit(true, false, false, true);
        emit DebtRemoved(user1, debtReduction, expectedNewDebt);
        vm.prank(user1);
        wethPool.removeDebt(debtReduction);

        Balances memory _after = _getBalances(user1);

        assertEq(_after.user.debt, _before.user.debt - debtReduction);
        assertEq(_after.user.collateral, _before.user.collateral);
        assertEq(_after.user.weth, _before.user.weth);
        assertEq(_after.user.pho, _before.user.pho - debtReduction);
        assertEq(_after.pool.debt, _before.pool.debt - debtReduction);
        assertEq(_after.pool.collateral, _before.pool.collateral);
        assertEq(_after.user.cr, expectedCR);
    }

    function testCannotRemoveDebtZeroValue() public {
        _openHealthyPosition(user1, ONE_THOUSAND_D18, 200);
        vm.expectRevert(abi.encodeWithSelector(ZeroValue.selector));
        vm.prank(user1);
        wethPool.removeDebt(0);
    }

    function testCannotRemoveDebtCDPNotActive() public {
        vm.expectRevert(abi.encodeWithSelector(CDPNotActive.selector));
        vm.prank(user1);
        wethPool.removeDebt(ONE_D18);
    }

    function testCannotRemoveDebtAmountTooHigh(uint256 debtReduction) public {
        _openHealthyPosition(user1, ONE_THOUSAND_D18, 175);
        debtReduction = bound(debtReduction, ONE_D18, ONE_THOUSAND_D18);

        vm.expectRevert(abi.encodeWithSelector(RequestedAmountTooHigh.selector));
        vm.prank(user1);
        wethPool.removeDebt(debtReduction);
    }

    /// close()

    function testClose() public {
        _openHealthyPosition(user1, ONE_THOUSAND_D18, 175);

        Balances memory _before = _getBalances(user1);
        uint256 protocolFee = _before.user.collateral * PROTOCOL_FEE / POINT_PRECISION;
        uint256 expectedCollateralBack = _before.user.collateral - protocolFee;

        vm.expectEmit(true, false, false, true);
        emit Closed(user1);
        vm.prank(user1);
        wethPool.close(_before.user.debt);

        Balances memory _after = _getBalances(user1);

        assertEq(_after.user.debt, 0);
        assertEq(_after.user.collateral, 0);
        assertEq(_after.user.weth, _before.user.weth + expectedCollateralBack);
        assertEq(_after.user.pho, _before.user.pho - _before.user.debt);
        assertEq(_after.pool.debt, _before.pool.debt - _before.user.debt);
        assertEq(_after.pool.collateral, _before.pool.collateral - _before.user.collateral);
        assertEq(_after.pool.earnedFees, _before.pool.earnedFees + protocolFee);
        assertEq(_after.pool.weth, _before.pool.weth - _before.user.collateral + protocolFee);
    }

    function testCannotCloseZeroValue() public {
        _openHealthyPosition(user1, ONE_THOUSAND_D18, 200);
        vm.expectRevert(abi.encodeWithSelector(ZeroValue.selector));
        vm.prank(user1);
        wethPool.close(0);
    }

    function testCannotCloseCDPNotActive() public {
        vm.expectRevert(abi.encodeWithSelector(CDPNotActive.selector));
        vm.prank(user1);
        wethPool.close(ONE_D18);
    }

    function testCannotCloseFullAmountNotPresent() public {
        _openHealthyPosition(user1, ONE_THOUSAND_D18, 175);

        vm.expectRevert(abi.encodeWithSelector(FullAmountNotPresent.selector));
        vm.prank(user1);
        wethPool.close(ONE_THOUSAND_D18 - 1);
    }

    /// liquidate()

    function testLiquidate() public {
        uint256 debtAmount = ONE_THOUSAND_D18;
        priceOracle.setWethUSDPrice(1500 * 10 ** 18);
        _openHealthyPosition(user1, debtAmount, 175);

        Balances memory _before = _getBalances(user1);
        UserBalance memory _liquidatorBefore = _getUserBalance(user2);

        priceOracle.setWethUSDPrice(1100 * 10 ** 18);

        uint256 protocolFee = _before.user.collateral * PROTOCOL_FEE / POINT_PRECISION;
        uint256 liquidationReward =
            (_before.user.collateral - protocolFee) * LIQUIDATION_REWARD / POINT_PRECISION;
        uint256 expectedLiquidatorAmount =
            wethPool.debtToCollateral(_before.user.debt) + liquidationReward;
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
        wethPool.liquidate(user1);

        Balances memory _after = _getBalances(user1);
        UserBalance memory _liquidatorAfter = _getUserBalance(user2);

        assertEq(_after.user.collateral, 0);
        assertEq(_after.user.debt, 0);
        assertEq(_after.user.weth, _before.user.weth + expectedCollateralBackToOwner);
        assertEq(_after.user.pho, _before.user.pho);
        assertEq(_liquidatorAfter.weth, _liquidatorBefore.weth + expectedLiquidatorAmount);
        assertEq(_liquidatorAfter.pho, _liquidatorBefore.pho - debtAmount);
        assertEq(_after.pool.weth, _before.pool.weth - _before.user.collateral + protocolFee);
        assertEq(_after.pool.collateral, _before.pool.collateral - _before.user.collateral);
        assertEq(_after.pool.debt, _before.pool.debt - debtAmount);
        assertEq(_after.pool.earnedFees, _before.pool.earnedFees + protocolFee);
    }

    function testCannotLiquidateCDPNotActive() public {
        vm.expectRevert(abi.encodeWithSelector(CDPNotActive.selector));
        vm.prank(user2);
        wethPool.liquidate(user1);
    }

    function testCannotLiquidateNotInLiquidationZone() public {
        _openHealthyPosition(user1, ONE_THOUSAND_D18, 175);
        vm.expectRevert(abi.encodeWithSelector(NotInLiquidationZone.selector));
        vm.prank(user2);
        wethPool.liquidate(user1);
    }

    /// computeCR()

    function testComputeCR() public {
        uint256 debtAmount = ONE_THOUSAND_D18;
        uint256 collateralAmount = 2 * ONE_D18;
        uint256 collateralInUSD = priceOracle.getPrice(WETH_ADDRESS) * collateralAmount / 10 ** 18;
        uint256 expectedCR = collateralInUSD * POINT_PRECISION / debtAmount;

        assertEq(expectedCR, wethPool.computeCR(collateralAmount, debtAmount));
    }

    /// calculateProtocolFee()

    function testCalculateProtocolFee(uint256 collateralAmount) public {
        collateralAmount = bound(collateralAmount, ONE_D18, ONE_THOUSAND_D18);
        uint256 expectedFee = collateralAmount * PROTOCOL_FEE / POINT_PRECISION;
        (uint256 actualFee, uint256 remainder) = wethPool.calculateProtocolFee(collateralAmount);
        assertEq(actualFee, expectedFee);
        assertEq(remainder, collateralAmount - expectedFee);
    }

    /// calculateLiquidationFee()

    function testCalculateLiquidationFee(uint256 collateralAmount) public {
        collateralAmount = bound(collateralAmount, ONE_D18, ONE_THOUSAND_D18);
        uint256 expectedFee = collateralAmount * LIQUIDATION_REWARD / POINT_PRECISION;
        uint256 actualFee = wethPool.calculateLiquidationFee(collateralAmount);
        assertEq(actualFee, expectedFee);
    }

    /// debtToCollateral()

    function testDebtToCollateral(uint256 debt) public {
        debt = bound(debt, ONE_THOUSAND_D18, ONE_MILLION_D18);
        uint256 collateralPrice = priceOracle.getPrice(WETH_ADDRESS);
        uint256 expectedCollateral = debt * 10 ** 18 / collateralPrice;
        assertEq(wethPool.debtToCollateral(debt), expectedCollateral);
    }

    /// collateralToUSD

    function testCollateralToUSD(uint256 collateralAmount) public {
        collateralAmount = bound(collateralAmount, ONE_D18, ONE_THOUSAND_D18);
        uint256 collateralPrice = priceOracle.getPrice(WETH_ADDRESS);
        uint256 expected = collateralAmount * collateralPrice / 10 ** 18;
        assertEq(wethPool.collateralToUSD(collateralAmount), expected);
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
        uint256 collateralAmount =
            wethPool.debtToCollateral(debtAmount * (cr * 10 ** 3) / POINT_PRECISION);
        vm.prank(user);
        wethPool.open(collateralAmount, debtAmount);
    }

    function _getPoolBalance() private returns (PoolBalance memory) {
        PoolBalance memory balance;
        (uint256 debt, uint256 collateral) = wethPool.balance();
        balance.debt = debt;
        balance.collateral = collateral;
        balance.earnedFees = wethPool.earnedFees();
        balance.pho = pho.balanceOf(address(wethPool));
        balance.weth = weth.balanceOf(address(wethPool));
        return balance;
    }

    function _getUserBalance(address user) private returns (UserBalance memory) {
        UserBalance memory balance;
        (uint256 debt, uint256 collateral) = wethPool.cdps(user);
        balance.debt = debt;
        balance.collateral = collateral;
        balance.pho = pho.balanceOf(user);
        balance.weth = weth.balanceOf(user);
        if (balance.collateral != 0 && balance.debt != 0) {
            balance.cr = wethPool.computeCR(balance.collateral, balance.debt);
        }
        return balance;
    }

    function _getBalances(address user) private returns (Balances memory) {
        Balances memory balance;
        balance.user = _getUserBalance(user);
        balance.pool = _getPoolBalance();
        return balance;
    }
}

interface IWETH is IERC20 {
    function deposit() external payable;
}
