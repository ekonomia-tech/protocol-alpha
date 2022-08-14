// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./Setup.t.sol";
import { EUSD } from "../src/contracts/EUSD.sol";
import {PriceOracle} from "../src/oracle/PriceOracle.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";


error Unauthorized();

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
    
    // EUSDPool eusdPool1 = new Pool(); // extra EUSD/USDC pool TODO - need actual import from Niv's commits
    // EUSDPool eusdPool2 = new Pool(); // extra EUSD/USDC pool TODO - need actual import from Niv's commits

    /// setup tests

    function testCreatorAddresssGetter() public {
        assertEq(pid.creator_address(), owner);
    }

    function testTimelockAddresssGetter() public {
        assertEq(pid.timelock_address(), timelock_address);
    }

    function testEUSDAddressGetter() public {
        EUSD _eusd = pid.eusd();
        address eusdAddress = address(_eusd);
        assertEq(eusdAddress, address(eusd));
    }

    // NOTE - TODO priceOracle (this to be expanded on in next sprint with oracle)
    function testPriceOracleGetter() public {
        PriceOracle _priceOracle = pid.priceOracle();
        address priceOracleAddress = address(_priceOracle);
        assertEq(priceOracleAddress, address(priceOracle));
    }

    // COLLATERALRATIOPAUSER
    // TODO - accessRoles usage TBD
    function testCRPauserGetter() public {
    }

    function testInitialLastCallTime() public {
        assertEq(pid.last_call_time(), 0);
    }
    
    function testEUSDStepGetter() public {
        assertEq(pid.EUSD_step(), 2500);
    }

    function testGCRGetter() public {
        assertEq(pid.global_collateral_ratio(), 1000000);
    }

    function testCooldownGetter() public {
        assertEq(pid.refresh_cooldown(), 3600);
    }

    function testPriceTargetGetter() public {
        assertEq(pid.price_target(), 1000000);
    }

    function testPriceBand() public {
        assertEq(pid.price_band(), 5000);
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
        vm.expectRevert("Not the owner, controller, or the governance timelock");
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

    /// Functional Test
    // to Niv, all the PID is doing is working with the collateral ratio and reporting back proper ones

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

    // globalCollateralValue() tests

    // @notice check GCV when only one EUSDPool compared to actual single pool's worth of collateral in protocol
    // check that collateralValue is correct as transactions happen within pools (people minting and redeeming more EUSD)
    // test when GCR is 100%
    function testGlobalCollateralValue() public {
        // NOTE - comparing total collateral value in USD to the actual collateral should be an independent test within pool contract too.
        uint256 mintAmount = 100e6;
        uint256 minOut = 90e18;
        uint256 expectedOut = mintAmount * (10 ** 12);

        _fundAndApproveUSDC(user1, address(pool_usdc), mintAmount, mintAmount);
        
        vm.startPrank(user1);
        pool_usdc.mint1t1EUSD(mintAmount, minOut);
        assertEq(eusd.balanceOf(user1), expectedOut);
        
        // test actual EUSD in USD price
        uint256 totalCollatUSD = (usdc.balanceOf(address(pool_usdc)) * priceOracle.getEUSDUSDPrice()) / PRICE_PRECISION ; // 1e6 * 1e6 / 1e6 (priceprecision)
        
        assertEq(totalCollatUSD, pid.globalCollateralValue());
        vm.stopPrank();
    }

    // single pool but test when GCR is <100% (Fractional)


    // // @notice check GCV() when only two EUSDPools active (both USDC) compared to actual worth of collateral in protocol after mints and redemptions
    // function testMultiPoolGlobalCollateralValue() public {
    //     // test vars while waiting for Niv's commit: 
    //     // usdcPool --> EUSDPool for USDC/EUSD
    //     // usdcPool.totalCollateral() --> total amount of collateral within a specific pool (in this case USDC) --> measured in the same decimals as the respective collateral, so 1e6 for USDC.
    //     // getEUSDUSDPrice() * usdcPool.totalCollateral() --> equates to what the total collateral value should be in USD
    //     // compare the above to the calculated total collateral here in dollar value
    //     // NOTE - comparing total collateral value in USD to the actual collateral should be an independent test within pool contract too.

    //     vm.startPrank(owner);
    //     eusdPools.addPool(eusdPool1);
    //     eusdPools.addPool(eusdPool2);
    //     vm.stopPrank();

    //     vm.startPrank(user1);
    //     usdcPool.mint(1000); // TODO - tie into actual pool contract once it is ready - mint EUSD to user1
    //     usdcPool2.mint(2000); // "
    //     // assertEq(usdc.balanceOf(usdcPool), usdcPool.totalCollateral()); // TODO - fix with proper getters in pool contract once it's pulled --> this test actually doesn't need to happen here, it should work and be tested in the usdcpool tests
        
    //     // test actual EUSD in USD price
    //     uint256 totalCollatUSD = ((eusdPool1.totalCollateral() + eusdPool2.totalCollateral()) * getEUSDUSDPrice()) / PRICE_PRECISION ; // 1e6 * 1e6 / 1e6 (priceprecision)
    //     // assertEq(totalCollatUSD, usdcPool.totalCollateralUSD()); // TODO - need a function from pool that returns totalCollateral in USD --> this test actually doesn't need to happen here, it should work and be tested in the usdcpool tests
        
    //     assertEq(totalCollatUSD, pid.globalCollateralValue()); // TODO - this is the only assertion that matters in this test.

    //     usdcPool2.redeem(1000);
    //     uint256 newTotalCollatUSD = ((eusdPool1.totalCollateral() + eusdPool2.totalCollateral()) * getEUSDUSDPrice()) / PRICE_PRECISION ; // 1e6 * 1e6 / 1e6 (priceprecision)
    //     assertEq(newTotalCollatUSD, pid.globalCollateralValue()); // TODO - this is the only assertion that matters in this test.
    // }

    // TODO in future - check multiple pool's worth of DIFFERENT collateral in protocol (making sure that it is pulling the a number of different collaterals and normalizing all of them)

    // refreshCollateralRatio() tests
   
    function testCannotRefreshPaused() public {
        vm.startPrank(owner);
        pid.toggleCollateralRatio();
        vm.expectRevert("Collateral Ratio has been paused");
        pid.refreshCollateralRatio();
        vm.stopPrank();
    }

   /// expectRevert when trying to call before refresh_cooldown is over from last last_call_time
    function testCannotRefreshBeforeCooldown() public {
        vm.startPrank(user1);
        vm.warp(3601);
        priceOracle.setEUSDUSDPrice(1e6 + 6000); // $1.006 USD/EUSD
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
        // uint256 simulatedTime;
        vm.warp(3601);
        priceOracle.setEUSDUSDPrice(1e6 + 6000); // $1.006 USD/EUSD

        while(pid.global_collateral_ratio() > pid.EUSD_step()) {
            uint256 oldCollateralRatio = pid.global_collateral_ratio();
            vm.expectEmit(false, false, false, true);
            emit CollateralRatioRefreshed(oldCollateralRatio - pid.EUSD_step());
            pid.refreshCollateralRatio();
            vm.warp(block.timestamp + 3601);
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
        vm.warp(3601);
        priceOracle.setEUSDUSDPrice(1e6 + 6000); // $1.006 USD/EUSD
        uint256 oldCollateralRatio1 = pid.global_collateral_ratio();
        vm.expectEmit(false, false, false, true);
        emit CollateralRatioRefreshed(oldCollateralRatio1 - pid.EUSD_step());
        pid.refreshCollateralRatio();
        assertEq(block.timestamp, pid.last_call_time());
        console.log("oldCR: %s and current CR: %s", oldCollateralRatio1, pid.global_collateral_ratio());

        uint256 oldCollateralRatio2 = pid.global_collateral_ratio();
        vm.warp(3601*2);
        priceOracle.setEUSDUSDPrice(1e6 + 6000); // $1.006 USD/EUSD
        vm.expectEmit(false, false, false, true);
        emit CollateralRatioRefreshed(oldCollateralRatio2 - pid.EUSD_step());
        pid.refreshCollateralRatio();
        assertEq(block.timestamp, pid.last_call_time());
        console.log("oldCR: %s and current CR: %s", oldCollateralRatio2, pid.global_collateral_ratio());

        uint256 oldCollateralRatio3 = pid.global_collateral_ratio();
        vm.warp(3601*3);
        priceOracle.setEUSDUSDPrice(1e6 - 6000); // $0.994 USD/EUSD
        vm.expectEmit(false, false, false, true);
        emit CollateralRatioRefreshed(oldCollateralRatio3 + pid.EUSD_step());
        pid.refreshCollateralRatio();
        assertEq(block.timestamp, pid.last_call_time());
        console.log("oldCR: %s and current CR: %s", oldCollateralRatio3, pid.global_collateral_ratio());
        vm.stopPrank();
    }

    /// @notice check high CR is maxed out at 100% CR
    function testHighCRRefreshCollateralRatio() public {
        vm.startPrank(user1);
        vm.warp(3601);
        priceOracle.setEUSDUSDPrice(1e6 - 6000); // $0.994 USD/EUSD
        uint256 oldCollateralRatio = pid.global_collateral_ratio();
        vm.expectEmit(false, false, false, true);
        emit CollateralRatioRefreshed(oldCollateralRatio);
        pid.refreshCollateralRatio();
        assertEq(block.timestamp, pid.last_call_time());
        vm.stopPrank();
    }

    /// Helpers

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

    function _getShare(address _to, uint256 _amount) private {
        vm.prank(address(pool_usdc));
        share.mint(_to, _amount);
    }

    function _approveShare(address _owner, address _spender, uint256 _amount) private {
        vm.prank(_owner);
        share.approve(_spender, _amount);
    }

    function _fundAndApproveShare(address _owner, address _spender, uint256 _amountIn, uint256 _amountOut) private {
        _getShare(_owner, _amountIn);
        _approveShare(_owner, _spender, _amountOut);
    }

// don't think I need this cause I'm not testing the actual precision and accuracy of minting and redeeming - that is pools.
    function _calculateParts(uint256 _totalEUSDOut) public returns(uint256 collRequired, uint256 shareRequired) {
        uint256 gcr = pid.global_collateral_ratio();
        uint256 sharePrice = priceOracle.getShareUSDPrice();
        uint256 usdcPrice = 1e6;

        uint256 totalDollarValue = _totalEUSDOut;
        
        uint256 collDollarPortion = (totalDollarValue * gcr) / 1e12;
        uint256 shareDollarPortion = (totalDollarValue * (1e6 - gcr)) / 1e6; 
        
        collRequired = collDollarPortion / (usdcPrice);
        shareRequired = (shareDollarPortion * 1e18)/(sharePrice); 
    }

}