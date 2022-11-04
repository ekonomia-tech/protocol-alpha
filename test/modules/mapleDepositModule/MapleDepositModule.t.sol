// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "forge-std/console2.sol";
import "../../BaseSetup.t.sol";
import "@modules/mapleDepositModule/MapleDepositModule.sol";
import "@modules/mapleDepositModule/IMplRewards.sol";
import "@modules/mapleDepositModule/IPool.sol";

contract MapleDepositModuleTest is BaseSetup {
    /// Errors
    error ZeroAddressDetected();
    error OverEighteenDecimals();
    error DepositTokenMustBeMaplePoolAsset();
    error CannotRedeemZeroTokens();

    /// Events
    event MapleDeposited(address indexed depositor, uint256 depositAmount, uint256 phoMinted);
    event MapleRedeemed(address indexed redeemer, uint256 redeemAmount);

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

        // Fund user with USDC
        vm.prank(richGuy);
        usdc.transfer(user1, TEN_THOUSAND_D6);

        // Fund user with WETH
        vm.prank(wethWhale);
        weth.transfer(user1, TEN_THOUSAND_D18);

        // Mint PHO to user
        vm.prank(address(moduleManager));
        kernel.mintPHO(address(user1), ONE_HUNDRED_D18);

        // Approve sending USDC to USDC MapleDeposit contract
        vm.startPrank(user1);
        usdc.approve(address(mapleDepositModuleUSDC), TEN_THOUSAND_D6);
        // Approve sending WETH to WETH MapleDeposit contract
        weth.approve(address(mapleDepositModuleWETH), TEN_THOUSAND_D18);

        // Allow sending PHO (redemptions) to MapleDeposit contracts
        pho.approve(address(mapleDepositModuleUSDC), TEN_THOUSAND_D18);
        pho.approve(address(mapleDepositModuleWETH), TEN_THOUSAND_D18);

        // Approve PHO burnFrom() via moduleManager calling kernel
        pho.approve(address(kernel), ONE_MILLION_D18);
        vm.stopPrank();
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

        // Stablecoin and PHO balances before
        MapleBalance memory before;
        before.userDepositTokenBalance = IERC20(_module.depositToken()).balanceOf(address(user1));
        before.moduleDepositTokenBalance =
            IERC20(_module.depositToken()).balanceOf(address(_module));
        before.userPHOBalance = pho.balanceOf(user1);
        before.userIssuedAmount = _module.issuedAmount(user1);
        before.userStakedAmount = _module.stakedAmount(user1);
        before.totalPHOSupply = pho.totalSupply();
        before.maplePoolBalance = _module.mplPool().balanceOf(address(_module));
        before.maplePoolRewardsBalance = _module.mplStakingAMO().balanceOf(address(_module));

        // Deposit - TODO: event
        vm.expectEmit(true, true, true, true);
        emit MapleDeposited(user1, _depositAmount, expectedIssuedAmount);
        vm.prank(user1);
        _module.deposit(_depositAmount);

        // DepositToken and PHO balances after
        MapleBalance memory aft;
        aft.userDepositTokenBalance = IERC20(_module.depositToken()).balanceOf(address(user1));
        aft.moduleDepositTokenBalance = IERC20(_module.depositToken()).balanceOf(address(_module));
        aft.userPHOBalance = pho.balanceOf(user1);
        aft.userIssuedAmount = _module.issuedAmount(user1);
        aft.userStakedAmount = _module.stakedAmount(user1);
        aft.totalPHOSupply = pho.totalSupply();
        aft.maplePoolBalance = _module.mplPool().balanceOf(address(_module));
        aft.maplePoolRewardsBalance = _module.mplStakingAMO().balanceOf(address(_module));

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

    // Only owner can call intendToWithdraw()
    function testCannotIntendToWithdrawOnlyOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(user1);
        mapleDepositModuleUSDC.intendToWithdraw();
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

        // Stablecoin and PHO balances before
        MapleBalance memory before;
        before.userDepositTokenBalance = IERC20(_module.depositToken()).balanceOf(address(user1));
        before.moduleDepositTokenBalance =
            IERC20(_module.depositToken()).balanceOf(address(_module));
        before.userPHOBalance = pho.balanceOf(user1);
        before.userIssuedAmount = _module.issuedAmount(user1);
        before.userStakedAmount = _module.stakedAmount(user1);
        before.totalPHOSupply = pho.totalSupply();
        before.maplePoolBalance = _module.mplPool().balanceOf(address(_module));
        before.maplePoolRewardsBalance = _module.mplStakingAMO().balanceOf(address(_module));

        vm.warp(intendToWithdrawTimestamp);
        vm.prank(owner);
        _module.intendToWithdraw();

        // Redeem - after cooldown period
        vm.warp(intendToWithdrawTimestamp + mplGlobalLpCooldownPeriod);
        vm.expectEmit(true, true, true, true);
        emit MapleRedeemed(user1, before.userIssuedAmount);
        vm.prank(user1);
        _module.redeem();

        // DepositToken and PHO balances after
        MapleBalance memory aft;
        aft.userDepositTokenBalance = IERC20(_module.depositToken()).balanceOf(address(user1));
        aft.moduleDepositTokenBalance = IERC20(_module.depositToken()).balanceOf(address(_module));
        aft.userPHOBalance = pho.balanceOf(user1);
        aft.userIssuedAmount = _module.issuedAmount(user1);
        aft.userStakedAmount = _module.stakedAmount(user1);
        aft.totalPHOSupply = pho.totalSupply();
        aft.maplePoolBalance = _module.mplPool().balanceOf(address(_module));
        aft.maplePoolRewardsBalance = _module.mplStakingAMO().balanceOf(address(_module));

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

    // Only owner can call getRewardMaple()
    function testCannotGetRewardOnlyOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(user1);
        mapleDepositModuleUSDC.getRewardMaple();
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
        // Deposit
        RewardsVars memory before;
        before.rewardPerToken = _module.mplStakingAMO().rewardPerToken();
        before.userRewardPerTokenPaid =
            _module.mplStakingAMO().userRewardPerTokenPaid(address(_module));
        before.lastUpdateTime = _module.mplStakingAMO().lastUpdateTime();
        before.lastTimeRewardApplicable = _module.mplStakingAMO().lastTimeRewardApplicable();
        before.periodFinish = _module.mplStakingAMO().periodFinish();
        before.blockTimestamp = block.timestamp;

        vm.prank(user1);
        _module.deposit(_depositAmount);

        RewardsVars memory afterDeposit;
        afterDeposit.rewardPerToken = _module.mplStakingAMO().rewardPerToken();
        afterDeposit.userRewardPerTokenPaid =
            _module.mplStakingAMO().userRewardPerTokenPaid(address(_module));
        afterDeposit.lastUpdateTime = _module.mplStakingAMO().lastUpdateTime();
        afterDeposit.lastTimeRewardApplicable = _module.mplStakingAMO().lastTimeRewardApplicable();
        afterDeposit.periodFinish = _module.mplStakingAMO().periodFinish();
        afterDeposit.blockTimestamp = block.timestamp;

        // Advance days to accrue rewards
        vm.warp(block.timestamp + 7 days);

        RewardsVars memory beforeRewards;
        beforeRewards.rewardPerToken = _module.mplStakingAMO().rewardPerToken();
        beforeRewards.userRewardPerTokenPaid =
            _module.mplStakingAMO().userRewardPerTokenPaid(address(_module));
        beforeRewards.lastUpdateTime = _module.mplStakingAMO().lastUpdateTime();
        beforeRewards.lastTimeRewardApplicable = _module.mplStakingAMO().lastTimeRewardApplicable();
        beforeRewards.periodFinish = _module.mplStakingAMO().periodFinish();
        beforeRewards.blockTimestamp = block.timestamp;

        uint256 beforeRewardsDeposited = _module.mplStakingAMO().balanceOf(address(_module));
        uint256 beforeRewardsBalance =
            IERC20(_module.mplStakingAMO().rewardsToken()).balanceOf(address(_module));
        uint256 beforeRewardsEarned = _module.mplStakingAMO().earned(address(_module));
        uint256 beforeRewardPerToken = _module.mplStakingAMO().rewardPerToken();
        uint256 beforeUserRewardPerTokenPaid =
            _module.mplStakingAMO().userRewardPerTokenPaid(address(_module));

        // Get reward
        vm.prank(owner);
        _module.getRewardMaple();

        uint256 afterRewardsDeposited = _module.mplStakingAMO().balanceOf(address(_module));
        uint256 afterRewardsBalance =
            IERC20(_module.mplStakingAMO().rewardsToken()).balanceOf(address(_module));
        uint256 afterRewardsEarned = _module.mplStakingAMO().earned(address(_module));

        // Check balances of reward tokens - note deposits stay same
        assertTrue(beforeRewardsBalance == 0);
        assertTrue(afterRewardsBalance > 0 && afterRewardsBalance == beforeRewardsEarned);
        assertTrue(afterRewardsEarned == 0);
        assertTrue(afterRewardsDeposited == beforeRewardsDeposited);
    }
}
