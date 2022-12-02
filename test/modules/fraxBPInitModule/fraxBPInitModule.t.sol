// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../../BaseSetup.t.sol";
import "@external/curve/ICurvePool.sol";
import "@external/curve/ICurveFactory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@modules/priceController/PriceController.sol";
import "@modules/fraxBPInitModule/FraxBPInitModule.sol";
import "forge-std/console2.sol";
import "@modules/fraxBPInitModule/interfaces/IGauge.sol";
import "@modules/fraxBPInitModule/interfaces/IGaugeController.sol";
import "@modules/fraxBPInitModule/interfaces/IMinter.sol";
import "@modules/fraxBPInitModule/LiquidityGauge.sol";
import "../../utils/VyperDeployer.sol";

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
    IGaugeController public curveGaugeController;
    IMinter public curveMinter;
    IGauge public curveLiquidityGauge;
    IERC20 public crv;

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

    struct SharesVars {
        uint256 shares;
        uint256 earned;
        uint256 totalShares;
    }

    VyperDeployer deployer;

    function setUp() public {
        fraxBPLP = IERC20(FRAXBP_LP_TOKEN);
        curveFactory = ICurveFactory(metaPoolFactoryAddress);
        curveGaugeController = IGaugeController(0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB);

        curveMinter = IMinter(0xd061D61a4d941c39E5453435B6345Dc261C2fcE0);
        crv = IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52);

        deployer = new VyperDeployer();
        console2.log("in setup, got vyper deployer..");

        // voting escrow contract:
        // 0x5f3b5DfEb7B28CDbD7FAba78963EE202a494e2A2

        // example of LiquidityGaugeReward
        // 0xA90996896660DEcC6E997655E065b23788857849

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

        console2.log("Setting up gauge..");

        curveLiquidityGauge = IGauge(
            new LiquidityGauge(
                address(fraxBPPHOMetapool),
                address(curveMinter),
                address(owner)
            )
        );

        // curveLiquidityGauge = IGauge(
        //     deployer.deployContract(
        //         "LiquidityGaugeReward",
        //         abi.encode(
        //             address(fraxBPPHOMetapool),
        //             address(curveMinter),
        //             0xDCB6A51eA3CA5d3Fd898Fd6564757c7aAeC3ca92,
        //             0xC011a73ee8576Fb46F5E1c5751cA3B9Fe0af2a6F,
        //             address(owner)
        //         )
        //     )
        // );

        console2.log("this is gauge address: ", address(curveLiquidityGauge));

        vm.prank(owner);
        fraxBPInitModule = new FraxBPInitModule(
            address(moduleManager),
            address(fraxBPPHOMetapool),
            address(pho),
            address(priceFeed),
            saleEndDate,
            redemptionStartDate,
            address(curveLiquidityGauge)
        );

        console2.log("made fraxBPInitModule.. now");

        // vm.prank(user1);
        // curveLiquidityGauge.set_approve_deposit(
        //     address(fraxBPInitModule),
        //     true
        // );

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

        // Do same for AMO
        vm.prank(user1);
        fraxBPPHOMetapool.approve(address(fraxBPInitModule.fraxBPInitModuleAMO()), TEN_THOUSAND_D18);

        console2.log("this is curveGaugeController address: ", address(curveGaugeController));

        // Reward contract: SNX rewards
        // 0xDCB6A51eA3CA5d3Fd898Fd6564757c7aAeC3ca92
        // Rewarded token: SNX
        // 0xC011a73ee8576Fb46F5E1c5751cA3B9Fe0af2a6F

        // // Still reverts in venv with vyper
        // curveLiquidityGauge = IGauge(
        //     deployer.deployContract(
        //         "LiquidityGaugeReward",
        //         abi.encode(
        //             address(fraxBPPHOMetapool),
        //             address(curveMinter),
        //             0xDCB6A51eA3CA5d3Fd898Fd6564757c7aAeC3ca92,
        //             0xC011a73ee8576Fb46F5E1c5751cA3B9Fe0af2a6F,
        //             address(owner)
        //         )
        //     )
        // );

        // curveLiquidityGauge = IGauge(
        //     0xA90996896660DEcC6E997655E065b23788857849
        // );

        console2.log("DEPLOYED GAUGE --------------> address is: ", address(curveLiquidityGauge));

        console2.log("ADDING GAUGE...");

        // Need msg.sender to be gauge admin
        vm.prank(0x40907540d8a6C65c637785e8f8B742ae6b0b9968);
        curveGaugeController.add_gauge(address(curveLiquidityGauge), 0, 100);

        console2.log("ADDED GAUGE...");

        uint256 weight = curveGaugeController.get_gauge_weight(address(curveLiquidityGauge));

        console2.log("THIS IS GAUGE WEIGHT: ", weight);
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
            redemptionStartDate,
            address(curveLiquidityGauge)
        );

        // Frax BP / PHO Pool
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        fraxBPInitModule = new FraxBPInitModule(
            address(moduleManager),
            address(0),
            address(pho),
            address(priceFeed),
            saleEndDate,
            redemptionStartDate,
            address(curveLiquidityGauge)
        );

        // PHO
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        fraxBPInitModule = new FraxBPInitModule(
            address(moduleManager),
            address(fraxBPPHOMetapool),
            address(0),
            address(priceFeed),
            saleEndDate,
            redemptionStartDate,
            address(curveLiquidityGauge)
        );

        // Oracle
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        fraxBPInitModule = new FraxBPInitModule(
            address(moduleManager),
            address(fraxBPPHOMetapool),
            address(pho),
            address(0),
            saleEndDate,
            redemptionStartDate,
            address(curveLiquidityGauge)
        );

        // Gauge
        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        fraxBPInitModule = new FraxBPInitModule(
            address(moduleManager),
            address(fraxBPPHOMetapool),
            address(pho),
            address(priceFeed),
            saleEndDate,
            redemptionStartDate,
            address(0)
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
            redemptionStartDate,
            address(curveLiquidityGauge)
        );

        vm.expectRevert(abi.encodeWithSelector(InvalidTimeWindows.selector));
        fraxBPInitModule = new FraxBPInitModule(
            address(moduleManager),
            address(fraxBPPHOMetapool),
            address(pho),
            address(priceFeed),
            saleEndDate,
            saleEndDate,
            address(curveLiquidityGauge)
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

        // // TODO: modify -> balance same b/c goes to AMO
        // assertApproxEqAbs(
        //     aft.moduleFraxBPPHOLPBalance,
        //     before.moduleFraxBPPHOLPBalance + _expectedMintAmount,
        //     deltaThreshold * 10**18
        // );

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

        // TODO: modify
        // assertApproxEqAbs(
        //     aft.moduleFraxBPPHOLPBalance,
        //     before.moduleFraxBPPHOLPBalance - before.userMetapoolBalance / 2,
        //     deltaThreshold * 10**18
        // );
        assertEq(aft.moduleFraxBPLPBalance, before.moduleFraxBPLPBalance);
        assertEq(aft.modulePHOBalance, before.modulePHOBalance);
        assertEq(aft.moduleUSDCBalance, before.moduleUSDCBalance);
        assertEq(aft.moduleFRAXBalance, before.moduleFRAXBalance);

        // Check issued amount goes down
        assertEq(aft.userMetapoolBalance, 0);

        // Check PHO supply same
        assertEq(aft.totalPHOSupply, before.totalPHOSupply);
    }

    // Test Reward
    function testRewardFraxBPInitModule() public {
        uint256 usdcDepositAmount = ONE_HUNDRED_D6;
        uint256 fraxDepositAmount = ONE_HUNDRED_D18;
        _testGetRewardAnyModule(
            usdcDepositAmount, fraxDepositAmount, fraxBPInitModule, saleEndDate - 500
        );
    }

    // Helper function to test FraxBPInit rewards from any module
    function _testGetRewardAnyModule(
        uint256 _usdcDepositAmount,
        uint256 _fraxDepositAmount,
        FraxBPInitModule _module,
        uint256 _depositTimestamp
    ) public {
        address moduleRewardPool = _module.fraxBPInitModuleAMO();

        vm.warp(_depositTimestamp);

        vm.prank(user1);
        _module.depositHelper(_usdcDepositAmount, _fraxDepositAmount);

        // Advance days to accrue rewards
        vm.warp(block.timestamp + 7 days);

        // Get reward
        vm.prank(owner);
        uint256 rewardsFraxBPInit = FraxBPInitModuleAMO(moduleRewardPool).getRewardFraxBPInit();

        // User gets the reward
        vm.warp(block.timestamp + 1 days);

        vm.prank(user1);
        FraxBPInitModuleAMO(moduleRewardPool).getReward(user1);

        uint256 finalUserRewardsBalance =
            IERC20(FraxBPInitModuleAMO(moduleRewardPool).rewardToken()).balanceOf(user1);

        // Check that user got rewards and protocol has none
        assertTrue(finalUserRewardsBalance > 0);
    }

    // Testing shares

    // // Test basic shares for deposit
    // function testSharesDepositFraxBPInitModule() public {
    //     uint256 usdcDepositAmount = ONE_HUNDRED_D6;
    //     uint256 fraxDepositAmount = ONE_HUNDRED_D18;
    //     uint256 expectedMint = 4 * fraxDepositAmount;
    //     _testSharesDepositAnyModule(
    //         usdcDepositAmount,
    //         fraxDepositAmount,
    //         expectedMint,
    //         address(crv),
    //         fraxBPInitModule,
    //         saleEndDate - 500,
    //         1
    //     );
    // }

    // Helper function to test shares for FraxBPInit deposit from any module
    function _testSharesDepositAnyModule(
        uint256 _usdcDepositAmount,
        uint256 _fraxDepositAmount,
        uint256 _expectedMintAmount,
        address _depositToken,
        FraxBPInitModule _module,
        uint256 _depositTimestamp,
        uint256 deltaThreshold
    ) public {
        uint256 usdcDepositAmount = _usdcDepositAmount;
        uint256 fraxDepositAmount = _fraxDepositAmount;
        FraxBPInitModuleAMO amo = FraxBPInitModuleAMO(_module.fraxBPInitModuleAMO());

        // Shares tracking before - users 1 & 2
        SharesVars memory before1;
        before1.shares = amo.sharesOf(user1);
        before1.earned = amo.earned(user1);
        before1.totalShares = amo.totalShares();
        SharesVars memory before2;
        before2.shares = amo.sharesOf(user2);
        before2.earned = amo.earned(user2);
        before2.totalShares = amo.totalShares();

        vm.warp(_depositTimestamp);

        // Deposit - user 1
        vm.prank(user1);
        _module.depositHelper(_usdcDepositAmount, _fraxDepositAmount);

        // Shares tracking afterwards for user 1
        SharesVars memory aft1;
        aft1.shares = amo.sharesOf(user1);
        aft1.earned = amo.earned(user1);
        aft1.totalShares = amo.totalShares();

        // After deposit 1 checks

        // Check that before state was all 0
        assertEq(before1.shares, 0);
        assertEq(before1.earned, 0);
        assertEq(before1.totalShares, 0);

        // Check that after state was modified except earned
        assertApproxEqAbs(aft1.shares, _expectedMintAmount, deltaThreshold * 10 ** 18);
        assertEq(aft1.earned, 0);
        assertApproxEqAbs(aft1.totalShares, _expectedMintAmount, deltaThreshold * 10 ** 18);

        // Deposit - user 2
        vm.prank(user2);
        _module.depositHelper(_usdcDepositAmount / 4, _fraxDepositAmount / 4);

        // Shares tracking afterwards for user 2
        SharesVars memory aft2;
        aft2.shares = amo.sharesOf(user2);
        aft2.earned = amo.earned(user2);
        aft2.totalShares = amo.totalShares();

        // After deposit 2 checks - total deposits was N, they put in N/4
        // Should have N/4 / (N/4 + N) = N/5 of total shares

        // Check that before state was all 0
        assertEq(before2.shares, 0);
        assertEq(before2.earned, 0);
        assertEq(before2.totalShares, 0);

        // Check that after state was modified except earned
        assertApproxEqAbs(aft2.shares, _expectedMintAmount / 5, deltaThreshold * 10 ** 18);
        assertEq(aft2.earned, 0);
        assertApproxEqAbs(
            aft2.totalShares,
            _expectedMintAmount + _expectedMintAmount / 5,
            deltaThreshold * 10 ** 18
        );
    }

    // Test Redeem
    function testSharesRedeemFraxBPInitModule() public {
        uint256 usdcDepositAmount = ONE_HUNDRED_D6;
        uint256 fraxDepositAmount = ONE_HUNDRED_D18;
        uint256 expectedMint = 4 * fraxDepositAmount;
        uint256 redeemAmount = 2 * ONE_HUNDRED_D18;
        uint256 redeemTimestamp = redemptionStartDate + 1;
        _testSharesDepositAnyModule(
            usdcDepositAmount,
            fraxDepositAmount,
            expectedMint,
            address(crv),
            fraxBPInitModule,
            saleEndDate - 500,
            1
        );
        uint256 startingTotalDeposits = fraxDepositAmount + fraxDepositAmount / 4;
        uint256 startingTotalShares = expectedMint + expectedMint / 5;
        _testSharesRedeemAnyModule(
            redeemAmount,
            address(crv),
            fraxBPInitModule,
            redeemTimestamp,
            startingTotalDeposits,
            startingTotalShares,
            1
        );
    }

    // Helper function to test shares for FraxBPInit redeem from any module
    function _testSharesRedeemAnyModule(
        uint256 _redeemAmount,
        address _depositToken,
        FraxBPInitModule _module,
        uint256 _redeemTimestamp,
        uint256 _startingTotalDeposits,
        uint256 _startingTotalShares,
        uint256 deltaThreshold
    ) public {
        // Convert expected issue amount based on stablecoin decimals
        address moduleRewardPool = _module.fraxBPInitModuleAMO();

        FraxBPInitModuleAMO amo = FraxBPInitModuleAMO(_module.fraxBPInitModuleAMO());

        // Shares tracking before - users 1 & 2
        SharesVars memory before1;
        before1.shares = amo.sharesOf(user1);
        before1.earned = amo.earned(user1);
        before1.totalShares = amo.totalShares();
        SharesVars memory before2;
        before2.shares = amo.sharesOf(user2);
        before2.earned = amo.earned(user2);
        before2.totalShares = amo.totalShares();

        vm.warp(_redeemTimestamp);

        // Redeem for user 1
        vm.warp(_redeemTimestamp);
        vm.prank(user1);
        _module.redeem();

        // Shares tracking afterwards - user 1
        SharesVars memory aft1;
        aft1.shares = amo.sharesOf(user1);
        aft1.earned = amo.earned(user1);
        aft1.totalShares = amo.totalShares();

        // // User 2 redeems
        vm.prank(user2);
        _module.redeem();

        // Shares tracking afterwards - user 2
        SharesVars memory aft2;
        aft2.shares = amo.sharesOf(user2);
        aft2.earned = amo.earned(user2);
        aft2.totalShares = amo.totalShares();

        // Check before state
        assertApproxEqAbs(before1.shares, 2 * _redeemAmount, deltaThreshold * 10 ** 18);
        assertEq(before1.earned, 0);
        assertApproxEqAbs(before1.totalShares, _startingTotalShares, deltaThreshold * 10 ** 18);
        assertApproxEqAbs(before2.shares, (2 * _redeemAmount) / 5, deltaThreshold * 10 ** 18);
        assertEq(before2.earned, 0);
        assertApproxEqAbs(before2.totalShares, _startingTotalShares, deltaThreshold * 10 ** 18);

        // Check after state
        assertEq(aft1.shares, 0);
        assertEq(aft1.earned, 0);
        assertApproxEqAbs(
            aft1.totalShares, _startingTotalShares - 2 * _redeemAmount, deltaThreshold * 10 ** 18
        );
        assertEq(aft2.shares, 0);
        assertEq(aft2.earned, 0);
        assertEq(aft2.totalShares, 0);
    }

    // Test Reward - TODO: patch up
    function testSharesRewardFraxBPInitModule() public {
        uint256 usdcDepositAmount = ONE_HUNDRED_D6;
        uint256 fraxDepositAmount = ONE_HUNDRED_D18;
        _testSharesGetRewardAnyModule(
            usdcDepositAmount, fraxDepositAmount, fraxBPInitModule, saleEndDate - 500, 1
        );
    }

    // Helper function to test FraxBPInit rewards from any module
    function _testSharesGetRewardAnyModule(
        uint256 _usdcDepositAmount,
        uint256 _fraxDepositAmount,
        FraxBPInitModule _module,
        uint256 _depositTimestamp,
        uint256 deltaThreshold
    ) public {
        uint256 usdcDepositAmount = _usdcDepositAmount;
        uint256 fraxDepositAmount = _fraxDepositAmount;
        address moduleRewardPool = _module.fraxBPInitModuleAMO();

        FraxBPInitModuleAMO amo = FraxBPInitModuleAMO(_module.fraxBPInitModuleAMO());

        // Shares tracking before - users 1 & 2
        SharesVars memory before1;
        before1.shares = amo.sharesOf(user1);
        before1.earned = amo.earned(user1);
        before1.totalShares = amo.totalShares();
        SharesVars memory before2;
        before2.shares = amo.sharesOf(user2);
        before2.earned = amo.earned(user2);
        before2.totalShares = amo.totalShares();

        vm.warp(_depositTimestamp);

        // Deposit - user 1 and user 2
        vm.prank(user1);
        _module.depositHelper(_usdcDepositAmount, _fraxDepositAmount);
        vm.prank(user2);
        _module.depositHelper(_usdcDepositAmount / 4, _fraxDepositAmount / 4);

        // Advance days to accrue rewards
        vm.warp(block.timestamp + 10 days);

        // Get reward
        vm.prank(owner);
        uint256 rewardsFraxBPInit = amo.getRewardFraxBPInit();

        // User gets the reward
        vm.warp(block.timestamp + 1 days);

        // Shares tracking afterwards - user 1
        SharesVars memory aft1;
        aft1.shares = amo.sharesOf(user1);
        aft1.earned = amo.earned(user1);
        aft1.totalShares = amo.totalShares();
        // Shares tracking afterwards - user 2
        SharesVars memory aft2;
        aft2.shares = amo.sharesOf(user2);
        aft2.earned = amo.earned(user2);
        aft2.totalShares = amo.totalShares();

        // TODO: modify

        // // Rewards for user 2 should be 1/5 of the rewards for user 1
        // // As per similar logic above, since user 2 has 1/5 total shares
        // assertTrue(aft1.earned > 0 && aft2.earned > 0);
        // assertApproxEqAbs(aft1.earned, 5 * aft2.earned, 1000 wei);

        // // Get actual rewards, earned() should reset to 0
        // vm.prank(user1);
        // amo.getReward(user1);
        // vm.prank(user2);
        // amo.getReward(user2);

        // aft1.earned = amo.earned(user1);
        // aft2.earned = amo.earned(user2);

        // assertEq(aft1.earned, 0);
        // assertEq(aft2.earned, 0);
    }
}
