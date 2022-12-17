// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {BaseSetup} from "../../BaseSetup.t.sol";
import "@modules/cdpModule/CDPPool.sol";
import "@modules/cdpModule/ICDPPool.sol";
import {wstETHCDPWrapper} from "@modules/cdpModule/wstETHCDPWrapper.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@oracle/IPriceOracle.sol";
import "@oracle/DummyOracle.sol";
import "@modules/interfaces/ERC20AddOns.sol";

contract wstETHCDPWrapperTest is BaseSetup {
    error NotETHVariant();

    struct PoolBalances {
        uint256 debt;
        uint256 collateral;
        uint256 feesCollected;
        uint256 pho;
        uint256 wstETH;
    }

    struct UserBalance {
        uint256 debt;
        uint256 collateral;
        uint256 pho;
        uint256 wstETH;
        uint256 stETH;
        uint256 wETH;
        uint256 ETH;
        uint256 cr;
    }

    struct Balances {
        UserBalance user;
        PoolBalances pool;
    }

    event Opened(address indexed user, uint256 debt, uint256 collateral);
    event CollateralAdded(address indexed user, uint256 addedCollateral, uint256 collateral);

    uint256 public constant MIN_CR = 170 * 10 ** 3;
    uint256 public constant LIQUIDATION_CR = 150 * 10 ** 3;
    uint256 public constant MIN_DEBT = ONE_THOUSAND_D18;
    uint256 public constant PROTOCOL_FEE = 5 * 10 ** 2;
    uint256 public constant LIQUIDATION_REWARD = 5 * 10 ** 3;
    uint256 public constant MINTING_CEILING = POOL_CEILING;
    uint256 public constant MAX_PPH = 10 ** 5;

    CDPPool public pool;
    wstETHCDPWrapper public cdpWrapper;
    ISTETH public STETH = ISTETH(STETH_ADDRESS);
    IWSTETH public WSTETH = IWSTETH(WSTETH_ADDRESS);

    function setUp() public {
        pool = new CDPPool(
            address(moduleManager),
            address(priceOracle),
            WSTETH_ADDRESS,
            address(TONTimelock),
            MIN_CR,
            LIQUIDATION_CR,
            MIN_DEBT,
            PROTOCOL_FEE
        );

        vm.prank(address(PHOTimelock));
        moduleManager.addModule(address(pool));

        vm.prank(address(TONTimelock));
        moduleManager.setPHOCeilingForModule(address(pool), MINTING_CEILING);

        vm.warp(block.timestamp + moduleManager.moduleDelay());

        moduleManager.executeCeilingUpdate(address(pool));

        cdpWrapper = new wstETHCDPWrapper(address(pool));

        vm.prank(address(cdpWrapper));
        WSTETH.approve(address(pool), type(uint256).max);

        /// user1 holds ETH
        vm.deal(user1, 20 * 10 ** 18);

        /// user2 hold wETH
        vm.deal(user2, 20 * 10 ** 18);
        vm.startPrank(user2);
        weth.deposit{value: (10 * 10 ** 18)}();
        weth.approve(address(cdpWrapper), type(uint256).max);
        vm.stopPrank();

        /// user3 holds stETH
        vm.deal(user3, 20 * 10 ** 18);
        vm.startPrank(user3);
        STETH.submit{value: 10 ether}(address(0));
        STETH.approve(address(cdpWrapper), type(uint256).max);
        vm.stopPrank();

        /// user4 holds wstETH
        vm.deal(user4, 20 * 10 ** 18);
        vm.startPrank(user4);
        STETH.submit{value: 10 ether}(address(0));
        STETH.approve(address(cdpWrapper), type(uint256).max);
        STETH.approve(WSTETH_ADDRESS, type(uint256).max);
        WSTETH.wrap(STETH.balanceOf(user4));
        WSTETH.approve(address(pool), type(uint256).max);
        vm.stopPrank();

        vm.prank(address(cdpWrapper));
        STETH.approve(address(WSTETH), type(uint256).max);

        vm.prank(user2);
        pho.approve(address(kernel), type(uint256).max);
    }

    /// open()

    function testOpenWithETH() public {
        uint256 collateralAmount = 2 * ONE_D18;
        uint256 debtAmount = ONE_THOUSAND_D18;

        uint256 expectedWst = WSTETH.getWstETHByStETH(collateralAmount);

        Balances memory _before = _getBalances(user1);

        vm.expectEmit(true, false, false, true);
        emit Opened(user1, debtAmount, expectedWst);
        vm.prank(user1);
        cdpWrapper.open{value: collateralAmount}(collateralAmount, debtAmount, address(0));

        Balances memory _after = _getBalances(user1);

        assertEq(_after.pool.collateral, _before.pool.collateral + expectedWst);
        assertEq(_after.pool.debt, _before.pool.debt + debtAmount);
        assertEq(_after.user.ETH, _before.user.ETH - collateralAmount);
    }

    function testOpenWithWETH() public {
        uint256 collateralAmount = 2 * ONE_D18;
        uint256 debtAmount = ONE_THOUSAND_D18;

        uint256 expectedWst = WSTETH.getWstETHByStETH(collateralAmount);

        Balances memory _before = _getBalances(user2);

        vm.expectEmit(true, false, false, true);
        emit Opened(user2, debtAmount, expectedWst);
        vm.prank(user2);
        cdpWrapper.open(collateralAmount, debtAmount, WETH_ADDRESS);

        Balances memory _after = _getBalances(user2);

        assertEq(_after.pool.collateral, _before.pool.collateral + expectedWst);
        assertEq(_after.pool.debt, _before.pool.debt + debtAmount);
        assertEq(_after.user.wETH, _before.user.wETH - collateralAmount);
    }

    function testOpenWithSTETH() public {
        uint256 collateralAmount = 2 * ONE_D18;
        uint256 debtAmount = ONE_THOUSAND_D18;

        uint256 expectedWst = WSTETH.getWstETHByStETH(collateralAmount);

        Balances memory _before = _getBalances(user3);

        vm.expectEmit(true, false, false, true);
        emit Opened(user3, debtAmount, expectedWst);
        vm.prank(user3);
        cdpWrapper.open(collateralAmount, debtAmount, STETH_ADDRESS);

        Balances memory _after = _getBalances(user3);

        assertApproxEqAbs(_after.pool.collateral, _before.pool.collateral + expectedWst, 1 wei);
        assertApproxEqAbs(_after.pool.debt, _before.pool.debt + debtAmount, 1 wei);
        assertApproxEqAbs(_after.user.stETH, _before.user.stETH - collateralAmount, 1 wei);
    }

    function testOpenWithWSTETH() public {
        uint256 collateralAmount = 2 * ONE_D18;
        uint256 debtAmount = ONE_THOUSAND_D18;

        Balances memory _before = _getBalances(user4);

        vm.expectEmit(true, false, false, true);
        emit Opened(user4, debtAmount, collateralAmount);
        vm.prank(user4);
        cdpWrapper.open(collateralAmount, debtAmount, WSTETH_ADDRESS);

        Balances memory _after = _getBalances(user4);

        assertEq(_after.pool.collateral, _before.pool.collateral + collateralAmount);
        assertEq(_after.pool.debt, _before.pool.debt + debtAmount);
        assertEq(_after.user.wstETH, _before.user.wstETH - collateralAmount);
    }

    /// addCollateral()

    function testAddCollateralETH() public {
        _openHealthyPosition(user1, 1000 * 10 ** 18, 250);

        uint256 collAddition = ONE_D18;
        uint256 expectedWstAddition = WSTETH.getWstETHByStETH(collAddition);

        Balances memory _before = _getBalances(user1);
        uint256 expectedNewCollateral = _before.user.collateral + expectedWstAddition;
        uint256 expectedCR =
            pool.computeCR(_before.user.collateral + expectedWstAddition, _before.user.debt);

        vm.expectEmit(true, false, false, true);
        emit CollateralAdded(user1, expectedWstAddition, expectedNewCollateral);
        vm.prank(user1);
        cdpWrapper.addCollateral{value: collAddition}(collAddition, address(0));

        Balances memory _after = _getBalances(user1);

        assertEq(_after.user.ETH, _before.user.ETH - collAddition);
        assertEq(_after.pool.collateral, _before.pool.collateral + expectedWstAddition);
        assertEq(_after.user.collateral, expectedNewCollateral);
        assertEq(_after.user.cr, expectedCR);
    }

    function testAddCollateralWETH() public {
        _openHealthyPosition(user2, 1000 * 10 ** 18, 250);

        uint256 collAddition = ONE_D18;
        uint256 expectedWstAddition = WSTETH.getWstETHByStETH(collAddition);

        Balances memory _before = _getBalances(user2);
        uint256 expectedNewCollateral = _before.user.collateral + expectedWstAddition;
        uint256 expectedCR =
            pool.computeCR(_before.user.collateral + expectedWstAddition, _before.user.debt);

        vm.expectEmit(true, false, false, true);
        emit CollateralAdded(user2, expectedWstAddition, expectedNewCollateral);
        vm.prank(user2);
        cdpWrapper.addCollateral(collAddition, WETH_ADDRESS);

        Balances memory _after = _getBalances(user2);

        assertEq(_after.user.wETH, _before.user.wETH - collAddition);
        assertEq(_after.pool.collateral, _before.pool.collateral + expectedWstAddition);
        assertEq(_after.user.collateral, expectedNewCollateral);
        assertEq(_after.user.cr, expectedCR);
    }

    function testAddCollateralSTETH() public {
        _openHealthyPosition(user3, 1000 * 10 ** 18, 250);

        uint256 collAddition = ONE_D18;
        uint256 expectedWstAddition = WSTETH.getWstETHByStETH(collAddition);

        Balances memory _before = _getBalances(user3);
        uint256 expectedNewCollateral = _before.user.collateral + expectedWstAddition;
        uint256 expectedCR =
            pool.computeCR(_before.user.collateral + expectedWstAddition, _before.user.debt);

        vm.expectEmit(true, false, false, true);
        emit CollateralAdded(user3, expectedWstAddition, expectedNewCollateral);
        vm.prank(user3);
        cdpWrapper.addCollateral(collAddition, STETH_ADDRESS);

        Balances memory _after = _getBalances(user3);

        assertApproxEqAbs(_after.user.stETH, _before.user.stETH - collAddition, 1 wei);
        assertApproxEqAbs(
            _after.pool.collateral, _before.pool.collateral + expectedWstAddition, 1 wei
        );
        assertApproxEqAbs(_after.user.collateral, expectedNewCollateral, 1 wei);
        assertApproxEqAbs(_after.user.cr, expectedCR, 1 wei);
    }

    function testAddCollateralWSTETH() public {
        _openHealthyPosition(user4, 1000 * 10 ** 18, 250);

        uint256 collAddition = ONE_D18;

        Balances memory _before = _getBalances(user4);
        uint256 expectedNewCollateral = _before.user.collateral + collAddition;
        uint256 expectedCR =
            pool.computeCR(_before.user.collateral + collAddition, _before.user.debt);

        vm.expectEmit(true, false, false, true);
        emit CollateralAdded(user4, collAddition, expectedNewCollateral);
        vm.prank(user4);
        cdpWrapper.addCollateral(collAddition, WSTETH_ADDRESS);

        Balances memory _after = _getBalances(user4);

        assertEq(_after.user.wstETH, _before.user.wstETH - collAddition);
        assertEq(_after.pool.collateral, _before.pool.collateral + collAddition);
        assertEq(_after.user.collateral, expectedNewCollateral);
        assertEq(_after.user.cr, expectedCR);
    }

    /// @notice opens a position for a user with certain debt and specific CR
    /// @param user the user that opens the position
    /// @param debtAmount the amount of debt to take
    /// @param cr that wanted CR in 3 digits - e.g. 200 = 200%
    function _openHealthyPosition(address user, uint256 debtAmount, uint256 cr)
        private
        returns (uint256, uint256)
    {
        require(cr >= (MIN_CR / 10 ** 3) && debtAmount >= MIN_DEBT);
        uint256 collateralAmount = pool.debtToCollateral(debtAmount * (cr * 10 ** 3) / MAX_PPH);
        vm.prank(user);
        cdpWrapper.open{value: collateralAmount}(collateralAmount, debtAmount, address(0));
    }

    function _getPoolBalances() private returns (PoolBalances memory) {
        PoolBalances memory balance;
        (uint256 debt, uint256 collateral) = pool.pool();
        balance.debt = debt;
        balance.collateral = collateral;
        balance.feesCollected = pool.feesCollected();
        balance.pho = pho.balanceOf(address(pool));
        balance.wstETH = WSTETH.balanceOf(address(pool));
        return balance;
    }

    function _getUserBalance(address user) private returns (UserBalance memory) {
        UserBalance memory balance;
        (uint256 debt, uint256 collateral) = pool.cdps(user);
        balance.debt = debt;
        balance.collateral = collateral;
        balance.pho = pho.balanceOf(user);
        balance.wstETH = WSTETH.balanceOf(user);
        balance.stETH = STETH.balanceOf(user);
        balance.wETH = weth.balanceOf(user);
        balance.ETH = user.balance;
        if (balance.collateral != 0 && balance.debt != 0) {
            balance.cr = pool.computeCR(balance.collateral, balance.debt);
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
