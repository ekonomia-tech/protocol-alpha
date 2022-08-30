// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseSetup.t.sol";
import {PHO} from "../src/contracts/PHO.sol";
import {DummyOracle} from "../src/oracle/DummyOracle.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PIDControllerTest is BaseSetup {
    /// EVENTS

    /// IPIDController events

    event CollateralRatioRefreshed(uint256 global_collateral_ratio);
    event RedemptionFeeSet(uint256 red_fee);
    event MintingFeeSet(uint256 min_fee);
    event PHOStepSet(uint256 new_step);
    event PriceTargetSet(uint256 new_price_target);
    event RefreshCooldownSet(uint256 new_cooldown);
    event TONAddressSet(address _TON_address);
    event ETHUSDOracleSet(address eth_usd_consumer_address);
    event TimelockSet(address new_timelock);
    event ControllerSet(address controller_address);
    event PriceBandSet(uint256 price_band);
    event PHOETHOracleSet(address PHO_oracle_addr, address weth_address);
    event TONEthOracleSet(address TON_oracle_addr, address weth_address);
    event CollateralRatioToggled(bool collateral_ratio_paused);

    /// IAccessControl events

    event RoleAdminChanged(
        bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole
    );
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /// Ownable events

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    uint256 poolMintAmount = 99750000;
    uint256 tonBurnAmount = 25 * 10 ** 16;
    uint256 minPHOOut = 80 * 10 ** 18;

    function setUp() public {
        _fundAndApproveUSDC(user1, address(pool_usdc), tenThousand_d6, tenThousand_d6);
        _fundAndApproveUSDC(user1, address(pool_usdc2), tenThousand_d6, tenThousand_d6);
        _fundAndApproveUSDC(user2, address(pool_usdc2), tenThousand_d6, tenThousand_d6);
    }

    /// Main PIDController Functional Tests

    /// globalCollateralValue() tests

    /// @notice check GCV when only one PHOPool compared to actual single pool's worth of collateral in protocol
    function testFullGlobalCollateralValue() public {
        uint256 expectedOut = oneHundred_d6 * (missing_decimals);
        uint256 userInitialPHO = pho.balanceOf(user1);

        vm.startPrank(user1);
        pool_usdc.mint1t1PHO(oneHundred_d6, minPHOOut);
        assertEq(pho.balanceOf(user1), expectedOut + userInitialPHO);
        // test actual PHO in USD price
        uint256 totalCollatUSD =
            (usdc.balanceOf(address(pool_usdc)) * priceOracle.getPHOUSDPrice()) / PRICE_PRECISION;
        assertEq(totalCollatUSD * missing_decimals, pid.globalCollateralValue());
        vm.stopPrank();
    }

    /// @notice check GCV when only one PHOPool when GCR is <100% (Fractional)
    function testFractionalGlobalCollateralValue() public {
        setPoolsAndDummyPrice(user1, overPeg);

        vm.startPrank(user1);
        pool_usdc.mintFractionalPHO(poolMintAmount, tonBurnAmount, minPHOOut);
        uint256 totalCollatUSD = usdc.balanceOf(address(pool_usdc)) * missing_decimals;
        assertEq(totalCollatUSD, pid.globalCollateralValue());
    }

    /// @notice check GCV test with two pools with GCR < 100% (both USDC)
    function testFractionalGCVMultiPools() public {
        setPoolsAndDummyPrice(user1, overPeg);
        vm.startPrank(user1);
        pool_usdc.mintFractionalPHO(poolMintAmount, tonBurnAmount, minPHOOut);
        pool_usdc2.mintFractionalPHO(poolMintAmount, tonBurnAmount, minPHOOut);

        uint256 totalCollatUSD1 = (usdc.balanceOf(address(pool_usdc))) * missing_decimals;
        uint256 totalCollatUSD2a = (usdc.balanceOf(address(pool_usdc2))) * missing_decimals;
        assertEq(totalCollatUSD1 + totalCollatUSD2a, pid.globalCollateralValue());

        // now test redeem and check global collateral value again
        uint256 phoIn = 1 * one_d18; // $1
        uint256 expectedTONOut = 0; // simplified to 0
        uint256 usdcOut = 900000; // 90 cents
        pho.approve(address(pool_usdc2), pho.balanceOf(user1));
        pool_usdc2.redeemFractionalPHO(phoIn, expectedTONOut, usdcOut);
        vm.roll(block.number + 1);
        pool_usdc2.collectRedemption();
        uint256 totalCollatUSD2b =
            ((usdc.balanceOf(address(pool_usdc2))) * one_d18) / PRICE_PRECISION;
        assertEq(totalCollatUSD1 + totalCollatUSD2b, pid.globalCollateralValue());
        vm.stopPrank();
    }

    // TODO in future - check multiple pool's worth of DIFFERENT collateral in protocol (making sure that it is pulling the a number of different collaterals and normalizing all of them)

    /// refreshCollateralRatio() tests

    function testCannotRefreshPaused() public {
        vm.startPrank(owner);
        pid.toggleCollateralRatio();
        vm.expectRevert("Collateral Ratio has been paused");
        pid.refreshCollateralRatio();
        vm.stopPrank();
    }

    /// @notice tests refresh_cooldown restricts properly
    function testCannotRefreshBeforeCooldown() public {
        vm.startPrank(user1);
        vm.warp(pid.refresh_cooldown() + 1);
        priceOracle.setPHOUSDPrice(overPeg); // $1.006 USD/PHO
        uint256 oldCollateralRatio = pid.global_collateral_ratio();
        vm.expectEmit(false, false, false, true);
        emit CollateralRatioRefreshed(oldCollateralRatio - pid.PHO_step());
        pid.refreshCollateralRatio();
        vm.expectRevert("Must wait for the refresh cooldown since last refresh");
        pid.refreshCollateralRatio();
        vm.stopPrank();
    }

    /// @notice test when global_collateral_ratio <= PHO_step
    function testRefreshGlobalCollateralRatioZero() public {
        vm.startPrank(user1);
        vm.warp(pid.refresh_cooldown() + 1);
        priceOracle.setPHOUSDPrice(overPeg); // $1.006 USD/PHO

        while (pid.global_collateral_ratio() > pid.PHO_step()) {
            uint256 oldCollateralRatio = pid.global_collateral_ratio();
            vm.expectEmit(false, false, false, true);
            emit CollateralRatioRefreshed(oldCollateralRatio - pid.PHO_step());
            pid.refreshCollateralRatio();
            vm.warp(block.timestamp + pid.refresh_cooldown() + 1);
        }

        // now GCR <= PHO_step
        vm.expectEmit(false, false, false, true);
        emit CollateralRatioRefreshed(0);
        pid.refreshCollateralRatio();
        vm.stopPrank();
    }

    /// @notice test that collateral ratio changes properly based on PHO_price_cur
    function testMultiRefreshCollateralRatio() public {
        vm.startPrank(user1);
        vm.warp(pid.refresh_cooldown() + 1);
        priceOracle.setPHOUSDPrice(overPeg); // $1.006 USD/PHO
        uint256 oldCollateralRatio1 = pid.global_collateral_ratio();
        vm.expectEmit(false, false, false, true);
        emit CollateralRatioRefreshed(oldCollateralRatio1 - pid.PHO_step());
        pid.refreshCollateralRatio();
        assertEq(block.timestamp, pid.last_call_time());

        uint256 oldCollateralRatio2 = pid.global_collateral_ratio();
        vm.warp((pid.refresh_cooldown() + 1) * 2);
        priceOracle.setPHOUSDPrice(overPeg); // $1.006 USD/PHO
        vm.expectEmit(false, false, false, true);
        emit CollateralRatioRefreshed(oldCollateralRatio2 - pid.PHO_step());
        pid.refreshCollateralRatio();
        assertEq(block.timestamp, pid.last_call_time());

        uint256 oldCollateralRatio3 = pid.global_collateral_ratio();
        vm.warp((pid.refresh_cooldown() + 1) * 3);
        priceOracle.setPHOUSDPrice(underPeg); // $0.994 USD/PHO
        vm.expectEmit(false, false, false, true);
        emit CollateralRatioRefreshed(oldCollateralRatio3 + pid.PHO_step());
        pid.refreshCollateralRatio();
        assertEq(block.timestamp, pid.last_call_time());
        vm.stopPrank();
    }

    /// @notice check high CR is maxed out at 100% CR
    function testHighCRRefreshCollateralRatio() public {
        vm.startPrank(user1);
        vm.warp(pid.refresh_cooldown() + 1);
        priceOracle.setPHOUSDPrice(underPeg); // $0.994 USD/PHO
        uint256 oldCollateralRatio = pid.global_collateral_ratio();
        vm.expectEmit(false, false, false, true);
        emit CollateralRatioRefreshed(oldCollateralRatio);
        pid.refreshCollateralRatio();
        assertEq(block.timestamp, pid.last_call_time());
        assertEq(oldCollateralRatio, pid.global_collateral_ratio());
        vm.stopPrank();
    }

    /// setup tests

    function testPIDConstructor() public {
        // NOTE - TODO priceOracle (this to be expanded on in next sprint with oracle)
        DummyOracle _priceOracle = pid.priceOracle();
        address priceOracleAddress = address(_priceOracle);
        assertEq(priceOracleAddress, address(priceOracle));

        PHO _pho = pid.pho();
        address phoAddress = address(_pho);
        assertEq(phoAddress, address(pho));
        assertEq(pid.creator_address(), owner);
        assertEq(pid.timelock_address(), timelock_address);

        assertEq(pid.hasRole(keccak256("COLLATERAL_RATIO_PAUSER"), owner), true);
        assertEq(pid.hasRole(keccak256("COLLATERAL_RATIO_PAUSER"), timelock_address), true);

        assertEq(pid.PHO_step(), 2500);
        assertEq(pid.global_collateral_ratio(), 1000000);
        assertEq(pid.refresh_cooldown(), 3600);
        assertEq(pid.price_target(), one_d6);
        assertEq(pid.price_band(), 5000);
        assertEq(pid.last_call_time(), 0);
    }

    /// Setter tests

    /// setRedemptionFee() tests

    function testCannotSetRedemptionFee() public {
        vm.expectRevert("Not the owner, controller, or the governance timelock");
        vm.prank(user1);
        pid.setRedemptionFee(7000);
    }

    function testOwnerSetRedemptionFee() public {
        vm.startPrank(owner);
        vm.expectEmit(false, false, false, true);
        emit RedemptionFeeSet(7000);
        pid.setRedemptionFee(7000);
        vm.stopPrank();
    }

    function testControllerSetRedemptionFee() public {
        vm.startPrank(controller);
        vm.expectEmit(false, false, false, true);
        emit RedemptionFeeSet(7000);
        pid.setRedemptionFee(7000);
        vm.stopPrank();
    }

    function testTimeLockSetRedemptionFee() public {
        vm.startPrank(timelock_address);
        vm.expectEmit(false, false, false, true);
        emit RedemptionFeeSet(7000);
        pid.setRedemptionFee(7000);
        vm.stopPrank();
    }

    /// setMintingFee() tests

    function testCannotSetMintingFee() public {
        vm.expectRevert("Not the owner, controller, or the governance timelock");
        vm.prank(user1);
        pid.setMintingFee(7000);
    }

    function testOwnerSetMintingFee() public {
        vm.startPrank(owner);
        vm.expectEmit(false, false, false, true);
        emit MintingFeeSet(7000);
        pid.setMintingFee(7000);
        vm.stopPrank();
    }

    function testControllerSetMintingFee() public {
        vm.startPrank(controller);
        vm.expectEmit(false, false, false, true);
        emit MintingFeeSet(7000);
        pid.setMintingFee(7000);
        vm.stopPrank();
    }

    function testTimeLockSetMintingFee() public {
        vm.startPrank(timelock_address);
        vm.expectEmit(false, false, false, true);
        emit MintingFeeSet(7000);
        pid.setMintingFee(7000);
        vm.stopPrank();
    }

    /// setPHOStep() tests

    function testCannotSetPHOStep() public {
        vm.expectRevert("Not the owner, controller, or the governance timelock");
        vm.prank(user1);
        pid.setPHOStep(5600);
    }

    function testOwnerSetPHOStep() public {
        vm.startPrank(owner);
        vm.expectEmit(false, false, false, true);
        emit PHOStepSet(5600);
        pid.setPHOStep(5600);
        vm.stopPrank();
    }

    function testControllerSetPHOStep() public {
        vm.startPrank(controller);
        vm.expectEmit(false, false, false, true);
        emit PHOStepSet(5600);
        pid.setPHOStep(5600);
        vm.stopPrank();
    }

    function testTimelockSetPHOStep() public {
        vm.startPrank(timelock_address);
        vm.expectEmit(false, false, false, true);
        emit PHOStepSet(5600);
        pid.setPHOStep(5600);
        vm.stopPrank();
    }

    /// setPriceTarget() tests

    function testCannotSetPriceTarget() public {
        vm.expectRevert("Not the owner, controller, or the governance timelock");
        vm.prank(user1);
        pid.setPriceTarget(1050000);
    }

    function testOwnerSetPriceTarget() public {
        vm.startPrank(owner);
        vm.expectEmit(false, false, false, true);
        emit PriceTargetSet(1050000);
        pid.setPriceTarget(1050000);
        vm.stopPrank();
    }

    function testControllerSetPriceTarget() public {
        vm.startPrank(controller);
        vm.expectEmit(false, false, false, true);
        emit PriceTargetSet(1050000);
        pid.setPriceTarget(1050000);
        vm.stopPrank();
    }

    function testTimelockSetPriceTarget() public {
        vm.startPrank(timelock_address);
        vm.expectEmit(false, false, false, true);
        emit PriceTargetSet(1050000);
        pid.setPriceTarget(1050000);
        vm.stopPrank();
    }

    /// setRefreshCooldown() tests

    function testCannotSetRefreshCooldown() public {
        vm.expectRevert("Not the owner, controller, or the governance timelock");
        vm.prank(user1);
        pid.setRefreshCooldown(4200);
    }

    function testOwnerSetRefreshCooldown() public {
        vm.startPrank(owner);
        vm.expectEmit(false, false, false, true);
        emit RefreshCooldownSet(4200);
        pid.setRefreshCooldown(4200);
        vm.stopPrank();
    }

    function testControllerSetRefreshCooldown() public {
        vm.startPrank(controller);
        vm.expectEmit(false, false, false, true);
        emit RefreshCooldownSet(4200);
        pid.setRefreshCooldown(4200);
        vm.stopPrank();
    }

    function testTimelockSetRefreshCooldown() public {
        vm.startPrank(timelock_address);
        vm.expectEmit(false, false, false, true);
        emit RefreshCooldownSet(4200);
        pid.setRefreshCooldown(4200);
        vm.stopPrank();
    }

    /// setTONAddress() tests

    function testCannotSetTONAddress() public {
        vm.expectRevert("Not the owner, controller, or the governance timelock");
        vm.prank(user1);
        pid.setTONAddress(dummyAddress);
    }

    function testCannotSetTONAddressZero() public {
        vm.expectRevert("Zero address detected");
        vm.prank(owner);
        pid.setTONAddress(address(0));
    }

    function testOwnerSetTONAddress() public {
        vm.startPrank(owner);
        vm.expectEmit(false, false, false, true);
        emit TONAddressSet(dummyAddress);
        pid.setTONAddress(dummyAddress);
        vm.stopPrank();
    }

    /// setTimelock() tests

    function testCannotSetTimelock() public {
        vm.expectRevert("Not the owner, controller, or the governance timelock");
        vm.prank(user1);
        pid.setTimelock(dummyAddress);
    }

    function testOwnerSetTimelock() public {
        vm.startPrank(owner);
        vm.expectEmit(false, false, false, true);
        emit TimelockSet(dummyAddress);
        pid.setTimelock(dummyAddress);
        vm.stopPrank();
    }

    function testControllerSetTimelock() public {
        vm.startPrank(controller);
        vm.expectEmit(false, false, false, true);
        emit TimelockSet(dummyAddress);
        pid.setTimelock(dummyAddress);
        vm.stopPrank();
    }

    function testTimelockSetTimelock() public {
        vm.startPrank(timelock_address);
        vm.expectEmit(false, false, false, true);
        emit TimelockSet(dummyAddress);
        pid.setTimelock(dummyAddress);
        vm.stopPrank();
    }

    /// setController() tests

    function testCannotSetController() public {
        vm.expectRevert("Not the owner, controller, or the governance timelock");
        vm.prank(user1);
        pid.setController(dummyAddress);
    }

    function testOwnerSetController() public {
        vm.startPrank(owner);
        vm.expectEmit(false, false, false, true);
        emit ControllerSet(dummyAddress);
        pid.setController(dummyAddress);
        vm.stopPrank();
    }

    function testControllerSetController() public {
        vm.startPrank(controller);
        vm.expectEmit(false, false, false, true);
        emit ControllerSet(dummyAddress);
        pid.setController(dummyAddress);
        vm.stopPrank();
    }

    function testTimelockSetController() public {
        vm.startPrank(timelock_address);
        vm.expectEmit(false, false, false, true);
        emit ControllerSet(dummyAddress);
        pid.setController(dummyAddress);
        vm.stopPrank();
    }

    /// setPriceBand() tests

    function testCannotSetPriceBand() public {
        vm.expectRevert("Not the owner, controller, or the governance timelock");
        vm.prank(user1);
        pid.setPriceBand(5600);
    }

    function testOwnerSetPriceBand() public {
        vm.startPrank(owner);
        vm.expectEmit(false, false, false, true);
        emit PriceBandSet(5600);
        pid.setPriceBand(5600);
        vm.stopPrank();
    }

    function testControllerSetPriceBand() public {
        vm.startPrank(controller);
        vm.expectEmit(false, false, false, true);
        emit PriceBandSet(5600);
        pid.setPriceBand(5600);
        vm.stopPrank();
    }

    function testTimelockSetPriceBand() public {
        vm.startPrank(timelock_address);
        vm.expectEmit(false, false, false, true);
        emit PriceBandSet(5600);
        pid.setPriceBand(5600);
        vm.stopPrank();
    }

    /// toggleCollateralRatio() tests

    function testFailToggleCR() public {
        vm.prank(user1);
        pid.toggleCollateralRatio();
    }

    function testPauserToggleCR() public {
        assertEq(pid.collateral_ratio_paused(), false);

        vm.startPrank(owner);
        vm.expectEmit(false, false, false, true);
        emit CollateralRatioToggled(true);
        pid.toggleCollateralRatio();
        vm.stopPrank();

        vm.startPrank(timelock_address);
        vm.expectEmit(false, false, false, true);
        emit CollateralRatioToggled(false);
        pid.toggleCollateralRatio();
        vm.stopPrank();
    }

    /// Price getter tests

    // NOTE - to be expanded on with oracles
    function testPHOPrice() public {
        assertEq(priceOracle.getPHOUSDPrice(), pid.PHO_price());
    }

    // TODO TON_price() test
    // NOTE - to be expanded on with oracles
    function testTONPrice() public {
        assertEq(priceOracle.ton_usd_price(), pid.TON_price());
    }

    // TODO eth_usd_price() test
    // NOTE - to be expanded on with oracles
    function testETHUSDPrice() public {
        assertEq(priceOracle.eth_usd_price(), pid.eth_usd_price());
    }

    /// Helpers

    function setPoolsAndDummyPrice(address _user, uint256 _price) public {
        vm.warp(pid.refresh_cooldown() + 1);
        priceOracle.setPHOUSDPrice(_price); // $1.006 USD/PHO
        pid.refreshCollateralRatio();
        vm.prank(owner);
        ton.transfer(_user, oneHundred_d18);

        vm.startPrank(_user);
        ton.approve(address(pool_usdc), ton.balanceOf(user1));
        ton.approve(address(pool_usdc2), ton.balanceOf(_user));

        vm.stopPrank();
    }
}
