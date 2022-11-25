// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "../../BaseSetup.t.sol";
import "@modules/mapleDepositModule/MapleDepositModule.sol";
import "@modules/mapleDepositModule/MapleModuleAMO.sol";
import "@modules/mapleDepositModule/IMplRewards.sol";
import "@modules/mapleDepositModule/IPool.sol";
import "@modules/interfaces/IModuleAMO.sol";

contract MapleDepositModuleTest is BaseSetup {
    /// Errors
    error ZeroAddressDetected();
    error OverEighteenDecimals();
    error DepositTokenMustBeMaplePoolAsset();
    error CannotRedeemZeroTokens();
    error OnlyOperator();
    error OnlyModule();
    error CannotStakeWhenOperatorWithdrawing();

    /// Events
    event Deposited(address indexed depositor, uint256 depositAmount, uint256 phoMinted);
    event Redeemed(address indexed redeemer, uint256 redeemAmount);

    // Track balance for stablecoins and PHO
    struct MapleBalance {
        uint256 userDepositTokenBalance;
        uint256 moduleDepositTokenBalance;
        uint256 userPHOBalance;
        uint256 userIssuedAmount;
        uint256 userStakedAmount;
        uint256 totalPHOSupply;
        uint256 maplePoolBalance;
        uint256 maplePoolRewardsBalance;
    }

    struct RewardsVars {
        uint256 rewardPerToken;
        uint256 userRewardPerTokenPaid;
        uint256 lastUpdateTime;
        uint256 lastTimeRewardApplicable;
        uint256 periodFinish;
        uint256 blockTimestamp;
    }

    struct SharesVars {
        uint256 shares;
        uint256 earned;
        uint256 totalShares;
    }

    // USDC
    MapleDepositModule public mapleDepositModuleUSDC;
    IMplRewards public mplRewardsUSDC;
    IPool public mplPoolUSDC;
    uint256 public mplPoolUSDCLockupPeriod;
    address public constant orthogonalPoolOwner = 0xd6d4Bcde6c816F17889f1Dd3000aF0261B03a196;
    address public constant orthogonalUSDCPool = 0xFeBd6F15Df3B73DC4307B1d7E65D46413e710C27;
    address public constant orthogonalUSDCRewards = 0x7869D7a3B074b5fa484dc04798E254c9C06A5e90;

    // WETH
    MapleDepositModule public mapleDepositModuleWETH;
    IMplRewards public mplRewardsWETH;
    IPool public mplPoolWETH;
    uint256 public mplPoolWETHLockupPeriod;
    address public constant mavenPoolOwner = 0xd6d4Bcde6c816F17889f1Dd3000aF0261B03a196;
    address public constant mavenWETHPool = 0x1A066b0109545455BC771E49e6EDef6303cb0A93;
    address public constant mavenWETHRewards = 0x0a76C7913C94F2AF16958FbDF9b4CF0bBdb159d8;

    // Global
    uint256 public constant mplGlobalLpCooldownPeriod = 864000;
    uint256 public constant mplGlobalLpWithdrawWindow = 172800;
    uint256 public moduleDelay;
    address public stakingToken = 0x6F6c8013f639979C84b756C7FC1500eB5aF18Dc4; // MPL-LP
    address rewardToken = 0x33349B282065b0284d756F0577FB39c158F935e6; // MPL

    function setUp() public {
        // Add price feeds
        vm.prank(owner);
        priceFeed.addFeed(USDC_ADDRESS, PRICEFEED_USDCUSD);

        vm.prank(owner);
        priceFeed.addFeed(WETH_ADDRESS, PRICEFEED_ETHUSD);

        // USDC - Orthogonal
        mplPoolUSDC = IPool(orthogonalUSDCPool);
        mplRewardsUSDC = IMplRewards(orthogonalUSDCRewards);
        mplPoolUSDCLockupPeriod = 2592000;
        mplPoolWETHLockupPeriod = 2592000;
        vm.prank(owner);
        mapleDepositModuleUSDC = new MapleDepositModule(
            address(moduleManager),
            address(kernel),
            address(pho),
            address(priceFeed),
            address(usdc),
            address(mplRewardsUSDC),
            address(mplPoolUSDC)
        );

        // WETH - Maven11
        mplPoolWETH = IPool(mavenWETHPool);
        mplRewardsWETH = IMplRewards(mavenWETHRewards);
        mplPoolWETHLockupPeriod = 15552000; // 15552000; //2592000;
        vm.prank(owner);
        mapleDepositModuleWETH = new MapleDepositModule(
            address(moduleManager),
            address(kernel),
            address(pho),
            address(priceFeed),
            address(weth),
            address(mplRewardsWETH),
            address(mplPoolWETH)
        );

        // Add module to ModuleManager
        vm.startPrank(PHOGovernance);
        moduleManager.addModule(address(mapleDepositModuleUSDC));
        moduleManager.addModule(address(mapleDepositModuleWETH));
        vm.stopPrank();

        // Increase PHO ceilings for modules
        vm.startPrank(TONGovernance);
        moduleManager.setPHOCeilingForModule(address(mapleDepositModuleUSDC), ONE_MILLION_D18);
        moduleManager.setPHOCeilingForModule(address(mapleDepositModuleWETH), ONE_MILLION_D18);
        vm.stopPrank();

        moduleDelay = moduleManager.moduleDelay();

        vm.warp(block.timestamp + moduleDelay);

        moduleManager.executeCeilingUpdate(address(mapleDepositModuleUSDC));
        moduleManager.executeCeilingUpdate(address(mapleDepositModuleWETH));

        // Fund users 1 & 2 with USDC
        vm.prank(richGuy);
        usdc.transfer(user1, TEN_THOUSAND_D6);
        vm.prank(richGuy);
        usdc.transfer(user2, TEN_THOUSAND_D6);

        // Fund users 1 & 2 with WETH
        vm.prank(wethWhale);
        weth.transfer(user1, TEN_THOUSAND_D18);
        vm.prank(wethWhale);
        weth.transfer(user2, TEN_THOUSAND_D18);

        // Mint PHO to users 1 & 2
        vm.prank(address(moduleManager));
        kernel.mintPHO(address(user1), ONE_HUNDRED_D18);
        vm.prank(address(moduleManager));
        kernel.mintPHO(address(user2), ONE_HUNDRED_D18);

        // Approve sending USDC to USDC MapleDeposit contract - user 1
        vm.startPrank(user1);
        usdc.approve(address(mapleDepositModuleUSDC), TEN_THOUSAND_D6);
        // Approve sending WETH to WETH MapleDeposit contract
        weth.approve(address(mapleDepositModuleWETH), TEN_THOUSAND_D18);

        // Do same for maple AMO
        usdc.approve(address(mapleDepositModuleUSDC.mapleModuleAMO()), TEN_THOUSAND_D6);
        weth.approve(address(mapleDepositModuleWETH.mapleModuleAMO()), TEN_THOUSAND_D18);

        // Allow sending PHO (redemptions) to MapleDeposit contracts
        pho.approve(address(mapleDepositModuleUSDC), TEN_THOUSAND_D18);
        pho.approve(address(mapleDepositModuleWETH), TEN_THOUSAND_D18);

        // Approve PHO burnFrom() via moduleManager calling kernel
        pho.approve(address(kernel), ONE_MILLION_D18);
        vm.stopPrank();

        // Allow transferring rewards

        address moduleRewardPoolUSDC = mapleDepositModuleUSDC.mapleModuleAMO();
        vm.prank(address(mapleDepositModuleUSDC));
        IERC20(rewardToken).approve(moduleRewardPoolUSDC, ONE_MILLION_D18);
        address moduleRewardPoolWETH = mapleDepositModuleWETH.mapleModuleAMO();
        vm.prank(address(mapleDepositModuleWETH));
        IERC20(rewardToken).approve(moduleRewardPoolWETH, ONE_MILLION_D18);

        // Approve sending USDC to USDC MapleDeposit contract - user 2
        vm.startPrank(user2);
        usdc.approve(address(mapleDepositModuleUSDC), TEN_THOUSAND_D6);
        // Approve sending WETH to WETH MapleDeposit contract
        weth.approve(address(mapleDepositModuleWETH), TEN_THOUSAND_D18);

        // Do same for maple AMO
        usdc.approve(address(mapleDepositModuleUSDC.mapleModuleAMO()), TEN_THOUSAND_D6);
        weth.approve(address(mapleDepositModuleWETH.mapleModuleAMO()), TEN_THOUSAND_D18);

        // Allow sending PHO (redemptions) to MapleDeposit contracts
        pho.approve(address(mapleDepositModuleUSDC), TEN_THOUSAND_D18);
        pho.approve(address(mapleDepositModuleWETH), TEN_THOUSAND_D18);

        // Approve PHO burnFrom() via moduleManager calling kernel
        pho.approve(address(kernel), ONE_MILLION_D18);
        vm.stopPrank();

        // Allow transferring rewards
        vm.prank(address(mapleDepositModuleUSDC));
        IERC20(rewardToken).approve(moduleRewardPoolUSDC, ONE_MILLION_D18);
        vm.prank(address(mapleDepositModuleWETH));
        IERC20(rewardToken).approve(moduleRewardPoolWETH, ONE_MILLION_D18);
    }

    // Cannot set any 0 addresses for constructor
    function testCannotMakeMapleDepositModuleWithZeroAddress() public {
        vm.startPrank(user1);

        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        mapleDepositModuleUSDC = new MapleDepositModule(
            address(0),
            address(kernel),
            address(pho),
            address(priceOracle),
            address(usdc),
            address(mplRewardsUSDC),
            address(mplPoolUSDC)
        );

        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        mapleDepositModuleUSDC = new MapleDepositModule(
            address(moduleManager),
            address(0),
            address(pho),
            address(priceOracle),
            address(usdc),
            address(mplRewardsUSDC),
            address(mplPoolUSDC)
        );

        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        mapleDepositModuleUSDC = new MapleDepositModule(
            address(moduleManager),
            address(kernel),
            address(0),
            address(priceOracle),
            address(usdc),
            address(mplRewardsUSDC),
            address(mplPoolUSDC)
        );

        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        mapleDepositModuleUSDC = new MapleDepositModule(
            address(moduleManager),
            address(kernel),
            address(pho),
            address(0),
            address(usdc),
            address(mplRewardsUSDC),
            address(mplPoolUSDC)
        );

        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        mapleDepositModuleUSDC = new MapleDepositModule(
            address(moduleManager),
            address(kernel),
            address(pho),
            address(priceOracle),
            address(0),
            address(mplRewardsUSDC),
            address(mplPoolUSDC)
        );

        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        mapleDepositModuleUSDC = new MapleDepositModule(
            address(moduleManager),
            address(kernel),
            address(pho),
            address(priceOracle),
            address(usdc),
            address(0),
            address(mplPoolUSDC)
        );

        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        mapleDepositModuleUSDC = new MapleDepositModule(
            address(moduleManager),
            address(kernel),
            address(pho),
            address(priceOracle),
            address(usdc),
            address(mplRewardsUSDC),
            address(0)
        );

        vm.stopPrank();
    }

    // Cannot have MPL pool asset not match depositToken
    function testCannotMakeMapleDepositModuleNonMatchingPoolAsset() public {
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(DepositTokenMustBeMaplePoolAsset.selector));
        mapleDepositModuleUSDC = new MapleDepositModule(
            address(moduleManager),
            address(kernel),
            address(pho),
            address(priceOracle),
            address(dai),
            address(mplRewardsUSDC),
            address(mplPoolUSDC)
        );
    }

    // Test basic deposit - USDC
    function testDepositMapleUSDC() public {
        uint256 depositAmount = ONE_HUNDRED_D6;
        _testDepositAnyModule(depositAmount, address(usdc), mapleDepositModuleUSDC);
    }

    // Test basic deposit - WETH
    function testDepositMapleWETH() public {
        uint256 depositAmount = ONE_HUNDRED_D18;
        _testDepositAnyModule(depositAmount, address(weth), mapleDepositModuleWETH);
    }

    // Helper function to test Maple deposit from any module
    function _testDepositAnyModule(
        uint256 _depositAmount,
        address _depositToken,
        MapleDepositModule _module
    ) public {
        // Convert expected issue amount based on stablecoin decimals
        uint256 scaledDepositAmount =
            _depositAmount * 10 ** (PHO_DECIMALS - _module.depositTokenDecimals());

        uint256 expectedIssuedAmount =
            ((scaledDepositAmount * priceFeed.getPrice(_depositToken)) / 10 ** 18);

        address moduleRewardPool = _module.mapleModuleAMO();

        // Stablecoin and PHO balances before
        MapleBalance memory before;
        before.userDepositTokenBalance = IERC20(_module.depositToken()).balanceOf(address(user1));
        before.moduleDepositTokenBalance =
            IERC20(_module.depositToken()).balanceOf(address(_module));
        before.userPHOBalance = pho.balanceOf(user1);
        before.userIssuedAmount = _module.issuedAmount(user1);
        before.userStakedAmount = MapleModuleAMO(moduleRewardPool).stakedAmount(user1);
        before.totalPHOSupply = pho.totalSupply();

        // Before -> _module, now -> moduleRewardPool
        before.maplePoolBalance = _module.mplPool().balanceOf(moduleRewardPool);
        before.maplePoolRewardsBalance =
            MapleModuleAMO(moduleRewardPool).mplRewards().balanceOf(moduleRewardPool);

        // Deposit - TODO: event
        vm.expectEmit(true, true, true, true);
        emit Deposited(user1, _depositAmount, expectedIssuedAmount);
        vm.prank(user1);
        _module.deposit(_depositAmount);

        // DepositToken and PHO balances after
        MapleBalance memory aft;
        aft.userDepositTokenBalance = IERC20(_module.depositToken()).balanceOf(address(user1));
        aft.moduleDepositTokenBalance = IERC20(_module.depositToken()).balanceOf(address(_module));
        aft.userPHOBalance = pho.balanceOf(user1);
        aft.userIssuedAmount = _module.issuedAmount(user1);
        aft.userStakedAmount = MapleModuleAMO(moduleRewardPool).stakedAmount(user1);
        aft.totalPHOSupply = pho.totalSupply();

        // Before -> _module, now -> moduleRewardPool
        aft.maplePoolBalance = _module.mplPool().balanceOf(moduleRewardPool);
        aft.maplePoolRewardsBalance =
            MapleModuleAMO(moduleRewardPool).mplRewards().balanceOf(moduleRewardPool);

        // User balance - depositToken down and PHO up
        assertEq(aft.userDepositTokenBalance + _depositAmount, before.userDepositTokenBalance);
        assertEq(aft.userPHOBalance, before.userPHOBalance + expectedIssuedAmount);

        // Deposit module balance - depositToken same (goes to Maple pool)
        assertEq(aft.moduleDepositTokenBalance, before.moduleDepositTokenBalance);

        // Check issued amount goes up
        assertEq(aft.userIssuedAmount, before.userIssuedAmount + expectedIssuedAmount);

        // Check staked amount goes up
        assertEq(aft.userStakedAmount, before.userStakedAmount + scaledDepositAmount);

        // Check PHO total supply goes up
        assertEq(aft.totalPHOSupply, before.totalPHOSupply + expectedIssuedAmount);

        // Check Maple pool balance goes up
        assertEq(aft.maplePoolBalance, before.maplePoolBalance + scaledDepositAmount);

        // Check Maple pool rewards balance goes up
        assertEq(aft.maplePoolRewardsBalance, before.maplePoolRewardsBalance + scaledDepositAmount);
    }

    // Only operator can call intendToWithdraw()
    function testCannotIntendToWithdrawOnlyOperator() public {
        address moduleRewardPool = mapleDepositModuleUSDC.mapleModuleAMO();
        vm.expectRevert(abi.encodeWithSelector(OnlyOperator.selector));
        vm.prank(user1);
        MapleModuleAMO(moduleRewardPool).intendToWithdraw();
    }

    // Only operator can call intendToWithdraw()
    function testCannotCancelWithdrawOnlyOperator() public {
        address moduleRewardPool = mapleDepositModuleUSDC.mapleModuleAMO();
        vm.expectRevert(abi.encodeWithSelector(OnlyOperator.selector));
        vm.prank(user1);
        MapleModuleAMO(moduleRewardPool).cancelWithdraw();
        assertEq(MapleModuleAMO(moduleRewardPool).isWithdrawing(), false);
    }

    // Basic intend to withdraw and cancel
    function testBasicWithdrawAndCancel() public {
        uint256 depositAmount = ONE_HUNDRED_D6;
        uint256 redeemAmount = ONE_HUNDRED_D6;
        uint256 intendToWithdrawTimestamp = block.timestamp + mplPoolUSDCLockupPeriod - 10 days;
        _testDepositAnyModule(depositAmount, address(usdc), mapleDepositModuleUSDC);
        address moduleRewardPool = mapleDepositModuleUSDC.mapleModuleAMO();

        // Intend to withdraw
        vm.prank(owner);
        MapleModuleAMO(moduleRewardPool).intendToWithdraw();
        assertEq(MapleModuleAMO(moduleRewardPool).isWithdrawing(), true);

        // Cannot deposit while withdrawing
        vm.expectRevert(abi.encodeWithSelector(CannotStakeWhenOperatorWithdrawing.selector));
        vm.prank(user1);
        mapleDepositModuleUSDC.deposit(depositAmount);

        // Cancel withdraw
        vm.prank(owner);
        MapleModuleAMO(moduleRewardPool).cancelWithdraw();
        assertEq(MapleModuleAMO(moduleRewardPool).isWithdrawing(), false);
    }

    // Test Redeem - USDC
    function testRedeemMapleUSDC() public {
        uint256 depositAmount = ONE_HUNDRED_D6;
        uint256 redeemAmount = ONE_HUNDRED_D6;
        uint256 intendToWithdrawTimestamp = block.timestamp + mplPoolUSDCLockupPeriod - 10 days;
        _testDepositAnyModule(depositAmount, address(usdc), mapleDepositModuleUSDC);
        _testRedeemAnyModule(
            redeemAmount, address(usdc), mapleDepositModuleUSDC, intendToWithdrawTimestamp
        );
    }

    // Test Redeem - WETH
    function testRedeemMapleWETH() public {
        uint256 depositAmount = ONE_HUNDRED_D18;
        uint256 redeemAmount = ONE_HUNDRED_D18;
        uint256 intendToWithdrawTimestamp = block.timestamp + mplPoolWETHLockupPeriod - 10 days;
        _testDepositAnyModule(depositAmount, address(weth), mapleDepositModuleWETH);
        _testRedeemAnyModule(
            redeemAmount, address(weth), mapleDepositModuleWETH, intendToWithdrawTimestamp
        );
    }

    // Helper function to test Maple redeem from any module
    function _testRedeemAnyModule(
        uint256 _redeemAmount,
        address _depositToken,
        MapleDepositModule _module,
        uint256 intendToWithdrawTimestamp
    ) public {
        // Convert expected issue amount based on stablecoin decimals
        uint256 scaledRedeemAmount =
            _redeemAmount * 10 ** (PHO_DECIMALS - _module.depositTokenDecimals());

        uint256 expectedRedeemAmount =
            (scaledRedeemAmount * priceFeed.getPrice(_depositToken)) / 10 ** 18;

        address moduleRewardPool = _module.mapleModuleAMO();

        // Stablecoin and PHO balances before
        MapleBalance memory before;
        before.userDepositTokenBalance = IERC20(_module.depositToken()).balanceOf(address(user1));
        before.moduleDepositTokenBalance =
            IERC20(_module.depositToken()).balanceOf(address(_module));
        before.userPHOBalance = pho.balanceOf(user1);
        before.userIssuedAmount = _module.issuedAmount(user1);
        before.userStakedAmount = MapleModuleAMO(moduleRewardPool).stakedAmount(user1);
        before.totalPHOSupply = pho.totalSupply();

        // These two - modules ---> _module
        before.maplePoolBalance = _module.mplPool().balanceOf(moduleRewardPool);
        before.maplePoolRewardsBalance =
            MapleModuleAMO(moduleRewardPool).mplRewards().balanceOf(moduleRewardPool);

        vm.warp(intendToWithdrawTimestamp);

        vm.prank(owner);
        MapleModuleAMO(moduleRewardPool).intendToWithdraw();

        // Redeem - after cooldown period
        vm.warp(intendToWithdrawTimestamp + mplGlobalLpCooldownPeriod);
        vm.expectEmit(true, true, true, true);
        emit Redeemed(user1, before.userIssuedAmount);
        vm.prank(user1);
        _module.redeem();

        // DepositToken and PHO balances after
        MapleBalance memory aft;
        aft.userDepositTokenBalance = IERC20(_module.depositToken()).balanceOf(address(user1));
        aft.moduleDepositTokenBalance = IERC20(_module.depositToken()).balanceOf(address(_module));
        aft.userPHOBalance = pho.balanceOf(user1);
        aft.userIssuedAmount = _module.issuedAmount(user1);
        aft.userStakedAmount = MapleModuleAMO(moduleRewardPool).stakedAmount(user1);
        aft.totalPHOSupply = pho.totalSupply();
        aft.maplePoolBalance = _module.mplPool().balanceOf(moduleRewardPool);
        aft.maplePoolRewardsBalance =
            MapleModuleAMO(moduleRewardPool).mplRewards().balanceOf(moduleRewardPool);

        // User balance - depositToken up and PHO down
        assertEq(aft.userDepositTokenBalance, before.userDepositTokenBalance + _redeemAmount);
        assertEq(aft.userPHOBalance + expectedRedeemAmount, before.userPHOBalance);

        // Deposit module balance - depositToken same (goes to Maple pool)
        assertEq(aft.moduleDepositTokenBalance, before.moduleDepositTokenBalance);

        // Check issued amount goes down
        assertEq(aft.userIssuedAmount + expectedRedeemAmount, before.userIssuedAmount);

        // Check staked amount goes down
        assertEq(aft.userStakedAmount + scaledRedeemAmount, before.userStakedAmount);

        // Check PHO total supply goes down
        assertEq(aft.totalPHOSupply + expectedRedeemAmount, before.totalPHOSupply);

        // Check Maple pool balance goes down
        assertEq(aft.maplePoolBalance + scaledRedeemAmount, before.maplePoolBalance);

        // Check Maple pool rewards balance goes down
        assertEq(aft.maplePoolRewardsBalance + scaledRedeemAmount, before.maplePoolRewardsBalance);
    }

    // Test Reward - USDC
    function testRewardUSDC() public {
        uint256 depositAmount = ONE_HUNDRED_D6;
        // Add USDC pool rewards amounts since prev amounts expired
        // i.e. last period of rewards was in the past so need to test with new rewards
        vm.prank(orthogonalPoolOwner);
        mplRewardsUSDC.notifyRewardAmount(ONE_HUNDRED_D18);
        _testGetRewardAnyModule(depositAmount, mapleDepositModuleUSDC);
    }

    // Test Reward - WETH
    function testRewardWETH() public {
        uint256 depositAmount = ONE_HUNDRED_D18;
        // Add WETH pool reward amounts since prev amounts expired
        // i.e. last period of rewards was in the past so need to test with new rewards
        vm.prank(mavenPoolOwner);
        mplRewardsWETH.notifyRewardAmount(ONE_HUNDRED_D18);
        _testGetRewardAnyModule(depositAmount, mapleDepositModuleWETH);
    }

    // Helper function to test Maple rewards from any module
    function _testGetRewardAnyModule(uint256 _depositAmount, MapleDepositModule _module) public {
        address moduleRewardPool = _module.mapleModuleAMO();

        // Deposit
        RewardsVars memory before;
        before.rewardPerToken = MapleModuleAMO(moduleRewardPool).mplRewards().rewardPerToken();
        before.userRewardPerTokenPaid =
            MapleModuleAMO(moduleRewardPool).mplRewards().userRewardPerTokenPaid(address(_module));
        before.lastUpdateTime = MapleModuleAMO(moduleRewardPool).mplRewards().lastUpdateTime();
        before.lastTimeRewardApplicable =
            MapleModuleAMO(moduleRewardPool).mplRewards().lastTimeRewardApplicable();
        before.periodFinish = MapleModuleAMO(moduleRewardPool).mplRewards().periodFinish();
        before.blockTimestamp = block.timestamp;

        vm.prank(user1);
        _module.deposit(_depositAmount);

        RewardsVars memory afterDeposit;
        afterDeposit.rewardPerToken = MapleModuleAMO(moduleRewardPool).mplRewards().rewardPerToken();
        afterDeposit.userRewardPerTokenPaid =
            MapleModuleAMO(moduleRewardPool).mplRewards().userRewardPerTokenPaid(address(_module));
        afterDeposit.lastUpdateTime = MapleModuleAMO(moduleRewardPool).mplRewards().lastUpdateTime();
        afterDeposit.lastTimeRewardApplicable =
            MapleModuleAMO(moduleRewardPool).mplRewards().lastTimeRewardApplicable();
        afterDeposit.periodFinish = MapleModuleAMO(moduleRewardPool).mplRewards().periodFinish();
        afterDeposit.blockTimestamp = block.timestamp;

        // Advance days to accrue rewards
        vm.warp(block.timestamp + 7 days);

        RewardsVars memory beforeRewards;
        beforeRewards.rewardPerToken =
            MapleModuleAMO(moduleRewardPool).mplRewards().rewardPerToken();
        beforeRewards.userRewardPerTokenPaid =
            MapleModuleAMO(moduleRewardPool).mplRewards().userRewardPerTokenPaid(address(_module));
        beforeRewards.lastUpdateTime =
            MapleModuleAMO(moduleRewardPool).mplRewards().lastUpdateTime();
        beforeRewards.lastTimeRewardApplicable =
            MapleModuleAMO(moduleRewardPool).mplRewards().lastTimeRewardApplicable();
        beforeRewards.periodFinish = MapleModuleAMO(moduleRewardPool).mplRewards().periodFinish();
        beforeRewards.blockTimestamp = block.timestamp;

        uint256 beforeRewardsDeposited =
            MapleModuleAMO(moduleRewardPool).mplRewards().balanceOf(address(_module));
        uint256 beforeRewardsBalance = IERC20(
            MapleModuleAMO(moduleRewardPool).mplRewards().rewardsToken()
        ).balanceOf(address(_module));
        uint256 beforeRewardsEarned =
            MapleModuleAMO(moduleRewardPool).mplRewards().earned(address(_module));

        // Get reward
        vm.prank(owner);
        //uint256 rewardsMaple = _module.getRewardMaple();
        uint256 rewardsMaple = MapleModuleAMO(moduleRewardPool).getRewardMaple();

        uint256 afterRewardsDeposited =
            MapleModuleAMO(moduleRewardPool).mplRewards().balanceOf(address(_module));
        uint256 afterRewardsBalance = IERC20(
            MapleModuleAMO(moduleRewardPool).mplRewards().rewardsToken()
        ).balanceOf(address(_module));
        uint256 afterRewardsPoolBalance = IERC20(
            MapleModuleAMO(moduleRewardPool).mplRewards().rewardsToken()
        ).balanceOf(address(moduleRewardPool));
        uint256 afterRewardsEarned =
            MapleModuleAMO(moduleRewardPool).mplRewards().earned(address(_module));

        // Check that reward was delivered to module pool
        assertTrue(beforeRewardsBalance == 0 && afterRewardsEarned == 0);
        assertTrue(afterRewardsBalance == 0 && afterRewardsPoolBalance > 0);
        assertTrue(afterRewardsDeposited == beforeRewardsDeposited);

        // User gets the reward

        // Add to rewards pool then call getReward()
        //vm.prank(owner);
        //IModuleAMO(moduleRewardPool).queueNewRewards(rewardsMaple);

        vm.warp(block.timestamp + 1 days);

        vm.prank(user1);
        MapleModuleAMO(moduleRewardPool).getReward(user1);

        uint256 finalUserRewardsBalance =
            IERC20(MapleModuleAMO(moduleRewardPool).mplRewards().rewardsToken()).balanceOf(user1);

        // Check that user got rewards and protocol has none
        assertTrue(finalUserRewardsBalance > 0);
    }

    /// Testing shares

    // Test basic shares for deposit - USDC
    function testSharesDepositMapleUSDC() public {
        uint256 depositAmount = ONE_HUNDRED_D6;
        _testSharesDepositAnyModule(depositAmount, address(usdc), mapleDepositModuleUSDC);
    }

    // Test basic shares for deposit - WETH
    function testSharesDepositMapleWETH() public {
        uint256 depositAmount = ONE_HUNDRED_D18;
        _testSharesDepositAnyModule(depositAmount, address(weth), mapleDepositModuleWETH);
    }

    // Helper function to test shares for Maple deposit from any module
    function _testSharesDepositAnyModule(
        uint256 _depositAmount,
        address _depositToken,
        MapleDepositModule _module
    ) public {
        MapleModuleAMO amo = MapleModuleAMO(_module.mapleModuleAMO());

        // Shares tracking before - users 1 & 2
        SharesVars memory before1;
        before1.shares = amo.sharesOf(user1);
        before1.earned = amo.earned(user1);
        before1.totalShares = amo.totalShares();
        SharesVars memory before2;
        before2.shares = amo.sharesOf(user2);
        before2.earned = amo.earned(user2);
        before2.totalShares = amo.totalShares();

        // Deposit - user 1
        vm.prank(user1);
        _module.deposit(_depositAmount);

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
        assertEq(aft1.shares, _depositAmount);
        assertEq(aft1.earned, 0);
        assertEq(aft1.totalShares, _depositAmount);

        // Deposit - user 2
        vm.prank(user2);
        _module.deposit(_depositAmount / 4);

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
        assertEq(aft2.shares, _depositAmount / 5);
        assertEq(aft2.earned, 0);
        assertEq(aft2.totalShares, _depositAmount + _depositAmount / 5);
    }

    // Test Redeem - USDC
    function testSharesRedeemMapleUSDC() public {
        uint256 depositAmount = ONE_HUNDRED_D6;
        uint256 redeemAmount = ONE_HUNDRED_D6;
        uint256 intendToWithdrawTimestamp = block.timestamp + mplPoolUSDCLockupPeriod - 10 days;
        _testSharesDepositAnyModule(depositAmount, address(usdc), mapleDepositModuleUSDC);
        uint256 startingTotalDeposits = depositAmount + depositAmount / 4;
        uint256 startingTotalShares = depositAmount + depositAmount / 5;
        _testSharesRedeemAnyModule(
            redeemAmount,
            address(usdc),
            mapleDepositModuleUSDC,
            intendToWithdrawTimestamp,
            startingTotalDeposits,
            startingTotalShares
        );
    }

    // Test Redeem - WETH
    function testSharesRedeemMapleWETH() public {
        uint256 depositAmount = ONE_HUNDRED_D18;
        uint256 redeemAmount = ONE_HUNDRED_D18;
        uint256 intendToWithdrawTimestamp = block.timestamp + mplPoolWETHLockupPeriod - 10 days;
        _testSharesDepositAnyModule(depositAmount, address(weth), mapleDepositModuleWETH);
        uint256 startingTotalDeposits = depositAmount + depositAmount / 4;
        uint256 startingTotalShares = depositAmount + depositAmount / 5;
        _testSharesRedeemAnyModule(
            redeemAmount,
            address(weth),
            mapleDepositModuleWETH,
            intendToWithdrawTimestamp,
            startingTotalDeposits,
            startingTotalShares
        );
    }

    // Helper function to test shares for Maple redeem from any module
    function _testSharesRedeemAnyModule(
        uint256 _redeemAmount,
        address _depositToken,
        MapleDepositModule _module,
        uint256 intendToWithdrawTimestamp,
        uint256 _startingTotalDeposits,
        uint256 _startingTotalShares
    ) public {
        // Convert expected issue amount based on stablecoin decimals
        address moduleRewardPool = _module.mapleModuleAMO();

        MapleModuleAMO amo = MapleModuleAMO(_module.mapleModuleAMO());

        // Shares tracking before - users 1 & 2
        SharesVars memory before1;
        before1.shares = amo.sharesOf(user1);
        before1.earned = amo.earned(user1);
        before1.totalShares = amo.totalShares();
        SharesVars memory before2;
        before2.shares = amo.sharesOf(user2);
        before2.earned = amo.earned(user2);
        before2.totalShares = amo.totalShares();

        vm.warp(intendToWithdrawTimestamp);

        vm.prank(owner);
        MapleModuleAMO(moduleRewardPool).intendToWithdraw();

        // Redeem for user 1 - after cooldown period
        vm.warp(intendToWithdrawTimestamp + mplGlobalLpCooldownPeriod);
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
        assertEq(before1.shares, _redeemAmount);
        assertEq(before1.earned, 0);
        assertEq(before1.totalShares, _startingTotalShares);
        assertEq(before2.shares, _redeemAmount / 5);
        assertEq(before2.earned, 0);
        assertEq(before2.totalShares, _startingTotalShares);

        // Check after state
        assertEq(aft1.shares, 0);
        assertEq(aft1.earned, 0);
        assertEq(aft1.totalShares, _startingTotalShares - _redeemAmount);
        assertEq(aft2.shares, 0);
        assertEq(aft2.earned, 0);
        assertEq(aft2.totalShares, 0);
    }

    // Test Reward - USDC
    function testSharesRewardUSDC() public {
        uint256 depositAmount = ONE_HUNDRED_D6;
        vm.prank(orthogonalPoolOwner);
        mplRewardsUSDC.notifyRewardAmount(ONE_HUNDRED_D18);
        _testSharesGetRewardAnyModule(depositAmount, mapleDepositModuleUSDC);
    }

    // Test Reward - WETH
    function testSharesRewardWETH() public {
        uint256 depositAmount = ONE_HUNDRED_D18;
        vm.prank(mavenPoolOwner);
        mplRewardsWETH.notifyRewardAmount(ONE_HUNDRED_D18);
        _testSharesGetRewardAnyModule(depositAmount, mapleDepositModuleWETH);
    }

    // Helper function to test Maple rewards from any module
    function _testSharesGetRewardAnyModule(uint256 _depositAmount, MapleDepositModule _module)
        public
    {
        address moduleRewardPool = _module.mapleModuleAMO();

        MapleModuleAMO amo = MapleModuleAMO(_module.mapleModuleAMO());

        // Shares tracking before - users 1 & 2
        SharesVars memory before1;
        before1.shares = amo.sharesOf(user1);
        before1.earned = amo.earned(user1);
        before1.totalShares = amo.totalShares();
        SharesVars memory before2;
        before2.shares = amo.sharesOf(user2);
        before2.earned = amo.earned(user2);
        before2.totalShares = amo.totalShares();

        // Deposit - user 1 and user 2
        vm.prank(user1);
        _module.deposit(_depositAmount);
        vm.prank(user2);
        _module.deposit(_depositAmount / 4);

        // Advance days to accrue rewards
        vm.warp(block.timestamp + 7 days);

        // Get reward
        vm.prank(owner);
        uint256 rewardsMaple = amo.getRewardMaple();

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

        // Rewards for user 2 should be 1/5 of the rewards for user 1
        // As per similar logic above, since user 2 has 1/5 total shares
        assertTrue(aft1.earned > 0 && aft2.earned > 0);
        assertApproxEqAbs(aft1.earned, 5 * aft2.earned, 100 wei);

        // Get actual rewards, earned() should reset to 0
        vm.prank(user1);
        amo.getReward(user1);
        vm.prank(user2);
        amo.getReward(user2);

        aft1.earned = amo.earned(user1);
        aft2.earned = amo.earned(user2);

        assertEq(aft1.earned, 0);
        assertEq(aft2.earned, 0);
    }
}
