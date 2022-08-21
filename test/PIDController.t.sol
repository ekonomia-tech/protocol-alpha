// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./Setup.t.sol";
import { EUSD } from "../src/contracts/EUSD.sol";
import {DummyOracle} from "../src/oracle/DummyOracle.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PIDControllerTest is Setup {    

    /// EVENTS

    /// IPIDController events

    event CollateralRatioRefreshed(uint256 global_collateral_ratio);
    event RedemptionFeeSet(uint256 red_fee);
    event MintingFeeSet(uint256 min_fee);
    event EUSDStepSet(uint256 new_step);
    event PriceTargetSet(uint256 new_price_target);
    event RefreshCooldownSet(uint256 new_cooldown);
    event SHAREAddressSet(address _SHARE_address);
    event ETHUSDOracleSet(address eth_usd_consumer_address);
    event TimelockSet(address new_timelock);
    event ControllerSet(address controller_address);
    event PriceBandSet(uint256 price_band);
    event EUSDETHOracleSet(address EUSD_oracle_addr, address weth_address);
    event SHAREEthOracleSet(address SHARE_oracle_addr, address weth_address);
    event CollateralRatioToggled(bool collateral_ratio_paused);

    /// IAccessControl events

    event RoleAdminChanged(
        bytes32 indexed role,
        bytes32 indexed previousAdminRole,
        bytes32 indexed newAdminRole
    );
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /// Ownable events

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// custom setup
    
    // function setup() public {
    //     vm.prank(user1);
    //     eusd.approve(address(pool_usdc), oneThousand);
    //     eusd.approve(address(pool_usdc2), oneThousand);
    //     vm.prank(user2);
    //     eusd.approve(address(pool_usdc), oneThousand);
    //     eusd.approve(address(pool_usdc2), oneThousand);
    //     vm.prank(user3);
    //     eusd.approve(address(pool_usdc), oneThousand);
    //     eusd.approve(address(pool_usdc2), oneThousand);
    // }

    /// Main PIDController Functional Tests

    /// globalCollateralValue() tests

    /// @notice check GCV when only one EUSDPool compared to actual single pool's worth of collateral in protocol
    function testFullGlobalCollateralValue() public {
        uint256 expectedOut = oneHundredUSDC * (10 ** 12);
        uint256 userInitialEUSD = eusd.balanceOf(owner);
        approvePools();
        vm.startPrank(owner);
        pool_usdc.mint1t1EUSD(oneHundredUSDC, minEUSDOut);
        assertEq(eusd.balanceOf(owner), expectedOut + userInitialEUSD);
        // test actual EUSD in USD price
        uint256 totalCollatUSD = (usdc.balanceOf(address(pool_usdc)) * priceOracle.getEUSDUSDPrice()) / PRICE_PRECISION; 
        assertEq(totalCollatUSD * missing_decimals, pid.globalCollateralValue());
        vm.stopPrank();
    }

    /// @notice check GCV when only one EUSDPool when GCR is <100% (Fractional)
    function testFractionalGlobalCollateralValue() public {
        setPoolsAndDummyPrice(user1, poolMintAmount * 2, poolMintAmount * 2, overPeg);
       
        vm.startPrank(user1);
        pool_usdc.mintFractionalEUSD(poolMintAmount, shareBurnAmount, minEUSDOut);        
        uint256 totalCollatUSD = usdc.balanceOf(address(pool_usdc)) * missing_decimals;
        assertEq(totalCollatUSD, pid.globalCollateralValue());
    }

    /// @notice check GCV test with two pools with GCR < 100% (both USDC)
    function testFractionalGCVMultiPools() public {
        setPoolsAndDummyPrice(user1, poolMintAmount*2, poolMintAmount*2, overPeg);
        vm.startPrank(user1);
        pool_usdc.mintFractionalEUSD(poolMintAmount, shareBurnAmount, minEUSDOut); 
        pool_usdc2.mintFractionalEUSD(poolMintAmount, shareBurnAmount, minEUSDOut);

        uint256 totalCollatUSD1 = (usdc.balanceOf(address(pool_usdc))) * missing_decimals; 
        uint256 totalCollatUSD2a = (usdc.balanceOf(address(pool_usdc2))) * missing_decimals; 
        assertEq(totalCollatUSD1 + totalCollatUSD2a, pid.globalCollateralValue());
        
        // now test redeem and check global collateral value again
        uint256 eusdIn = 1 * 10 ** 18; // $1
        uint256 expectedShareOut = 0; // simplified to 0
        uint256 usdcOut = 900000; // 90 cents
        eusd.approve(address(pool_usdc2), eusd.balanceOf(user1));
        pool_usdc2.redeemFractionalEUSD(eusdIn, expectedShareOut, usdcOut);
        vm.roll(block.number + 1);
        pool_usdc2.collectRedemption();
        uint256 totalCollatUSD2b = ((usdc.balanceOf(address(pool_usdc2))) * 10 ** 18) / PRICE_PRECISION; 
        assertEq(totalCollatUSD1 + totalCollatUSD2b , pid.globalCollateralValue());
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
        priceOracle.setEUSDUSDPrice(overPeg); // $1.006 USD/EUSD
        uint256 oldCollateralRatio = pid.global_collateral_ratio();
        vm.expectEmit(false, false, false, true);
        emit CollateralRatioRefreshed(oldCollateralRatio - pid.EUSD_step());
        pid.refreshCollateralRatio();
        vm.expectRevert("Must wait for the refresh cooldown since last refresh");
        pid.refreshCollateralRatio();
        vm.stopPrank();
    }

    /// @notice test when global_collateral_ratio <= EUSD_step
    function testRefreshGlobalCollateralRatioZero() public {
        vm.startPrank(user1);
        vm.warp(pid.refresh_cooldown() + 1);
        priceOracle.setEUSDUSDPrice(overPeg); // $1.006 USD/EUSD

        while(pid.global_collateral_ratio() > pid.EUSD_step()) {
            uint256 oldCollateralRatio = pid.global_collateral_ratio();
            vm.expectEmit(false, false, false, true);
            emit CollateralRatioRefreshed(oldCollateralRatio - pid.EUSD_step());
            pid.refreshCollateralRatio();
            vm.warp(block.timestamp + pid.refresh_cooldown() + 1);
        }

        // now GCR <= EUSD_step
        vm.expectEmit(false, false, false, true);
        emit CollateralRatioRefreshed(0);
        pid.refreshCollateralRatio();
        vm.stopPrank();
    }

    /// @notice test that collateral ratio changes properly based on EUSD_price_cur
    function testMultiRefreshCollateralRatio() public {
        vm.startPrank(user1);
        vm.warp(pid.refresh_cooldown() + 1);
        priceOracle.setEUSDUSDPrice(overPeg); // $1.006 USD/EUSD
        uint256 oldCollateralRatio1 = pid.global_collateral_ratio();
        vm.expectEmit(false, false, false, true);
        emit CollateralRatioRefreshed(oldCollateralRatio1 - pid.EUSD_step());
        pid.refreshCollateralRatio();
        assertEq(block.timestamp, pid.last_call_time());

        uint256 oldCollateralRatio2 = pid.global_collateral_ratio();
        vm.warp((pid.refresh_cooldown() + 1) * 2);
        priceOracle.setEUSDUSDPrice(overPeg); // $1.006 USD/EUSD
        vm.expectEmit(false, false, false, true);
        emit CollateralRatioRefreshed(oldCollateralRatio2 - pid.EUSD_step());
        pid.refreshCollateralRatio();
        assertEq(block.timestamp, pid.last_call_time());

        uint256 oldCollateralRatio3 = pid.global_collateral_ratio();
        vm.warp((pid.refresh_cooldown() + 1) * 3);
        priceOracle.setEUSDUSDPrice(underPeg); // $0.994 USD/EUSD
        vm.expectEmit(false, false, false, true);
        emit CollateralRatioRefreshed(oldCollateralRatio3 + pid.EUSD_step());
        pid.refreshCollateralRatio();
        assertEq(block.timestamp, pid.last_call_time());
        vm.stopPrank();
    }

    /// @notice check high CR is maxed out at 100% CR
    function testHighCRRefreshCollateralRatio() public {
        vm.startPrank(user1);
        vm.warp(pid.refresh_cooldown() + 1);
        priceOracle.setEUSDUSDPrice(underPeg); // $0.994 USD/EUSD
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

        EUSD _eusd = pid.eusd();
        address eusdAddress = address(_eusd);
        assertEq(eusdAddress, address(eusd));
        assertEq(pid.creator_address(), owner);
        assertEq(pid.timelock_address(), timelock_address);
        
        assertEq(pid.hasRole(keccak256("COLLATERAL_RATIO_PAUSER"), owner), true);
        assertEq(pid.hasRole(keccak256("COLLATERAL_RATIO_PAUSER"), timelock_address), true);

        assertEq(pid.EUSD_step(), 2500);
        assertEq(pid.global_collateral_ratio(), 1000000);
        assertEq(pid.refresh_cooldown(), 3600);
        assertEq(pid.price_target(), 10 ** 6);
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

    /// setEUSDStep() tests

    function testCannotSetEUSDStep() public {
        vm.expectRevert("Not the owner, controller, or the governance timelock");
        vm.prank(user1);
        pid.setEUSDStep(5600);
    }

    function testOwnerSetEUSDStep() public {
        vm.startPrank(owner);
        vm.expectEmit(false, false, false, true);
        emit EUSDStepSet(5600);
        pid.setEUSDStep(5600);
        vm.stopPrank();
    }

    function testControllerSetEUSDStep() public {
        vm.startPrank(controller);
        vm.expectEmit(false, false, false, true);
        emit EUSDStepSet(5600);
        pid.setEUSDStep(5600);
        vm.stopPrank();
    }

    function testTimelockSetEUSDStep() public {
        vm.startPrank(timelock_address);
        vm.expectEmit(false, false, false, true);
        emit EUSDStepSet(5600);
        pid.setEUSDStep(5600);
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

    /// setShareAddress() tests

    function testCannotSetShareAddress() public {
        vm.expectRevert("Not the owner, controller, or the governance timelock");
        vm.prank(user1);
        pid.setSHAREAddress(dummyAddress);
    }

     function testCannotSetShareAddressZero() public {
        vm.expectRevert("Zero address detected");
        vm.prank(owner);
        pid.setSHAREAddress(address(0));
    }

    function testOwnerSetShareAddress() public {
        vm.startPrank(owner);
        vm.expectEmit(false, false, false, true);
        emit SHAREAddressSet(dummyAddress);
        pid.setSHAREAddress(dummyAddress);
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
    function testEUSDPrice() public {
        assertEq(priceOracle.getEUSDUSDPrice(), pid.EUSD_price());
    }

    // TODO SHARE_price() test
    // NOTE - to be expanded on with oracles
    function testSharePrice() public {
        assertEq(priceOracle.share_usd_price(), pid.SHARE_price());
    }


    // TODO eth_usd_price() test
    // NOTE - to be expanded on with oracles
    function testETHUSDPrice() public {
        assertEq(priceOracle.eth_usd_price(), pid.eth_usd_price());
    }

    /// Helpers

    function approvePools() public {
        _fundAndApproveUSDC(owner, address(pool_usdc), tenThousandUSDC, tenThousandUSDC);
        _fundAndApproveUSDC(user1, address(pool_usdc), tenThousandUSDC, tenThousandUSDC);
        _fundAndApproveUSDC(user2, address(pool_usdc), tenThousandUSDC, tenThousandUSDC);
        _fundAndApproveUSDC(user3, address(pool_usdc), tenThousandUSDC, tenThousandUSDC);
        _fundAndApproveUSDC(user1, address(pool_usdc2), tenThousandUSDC, tenThousandUSDC);
        _fundAndApproveUSDC(owner, address(pool_usdc2), tenThousandUSDC, tenThousandUSDC);

    }

    function setPoolsAndDummyPrice(address _user, uint256 _amountIn, uint256 _amountOut, uint256 _price) public {
        approvePools();

        // _fundAndApproveUSDC(_user, address(pool_usdc), _amountIn, _amountOut);
        vm.warp(pid.refresh_cooldown() + 1);
        priceOracle.setEUSDUSDPrice(_price); // $1.006 USD/EUSD
        pid.refreshCollateralRatio();
        vm.prank(owner);
        share.transfer(_user, oneHundred);

        vm.startPrank(_user);
        share.approve(address(pool_usdc), share.balanceOf(user1));
        share.approve(address(pool_usdc2), share.balanceOf(_user));
        // usdc.approve(address(pool_usdc2), usdc.balanceOf(_user));
        vm.stopPrank();
    }

    function _getUSDC(address to, uint256 _amount) private {
        vm.prank(richGuy);
        usdc.transfer(to, _amount);
    }

    function _approveUSDC(address _owner, address _spender, uint256 _amount) private {
        vm.prank(_owner);
        usdc.approve(_spender, _amount);
    }

    function _fundAndApproveUSDC(address _owner, address _spender, uint256 _amountIn, uint256 _amountOut) private {
        _getUSDC(_owner, _amountIn);
        _approveUSDC(_owner, _spender, _amountOut);
    }

}