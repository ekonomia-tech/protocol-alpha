// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "../../BaseSetup.t.sol";
import "@modules/liquityModule/LiquityDepositModule.sol";
import "@modules/liquityModule/LiquityModuleAMO.sol";
import "@modules/interfaces/IModuleAMO.sol";

contract LiquityDepositModuleTest is BaseSetup {
    /// Errors
    error ZeroAddressDetected();
    error CannotDepositZero();
    error CannotRedeemZeroTokens();

    /// Events
    event Deposited(address indexed depositor, uint256 depositAmount, uint256 phoMinted);
    event Redeemed(address indexed redeemer, uint256 redeemAmount);

    // Track balance for stablecoins and PHO
    struct LiquityBalance {
        uint256 userStablecoinBalance;
        uint256 moduleStablecoinBalance;
        uint256 userPHOBalance;
        uint256 userIssuedAmount;
        uint256 userStakedAmount;
        uint256 totalPHOSupply;
        uint256 liquityPoolDeposits;
        uint256 liquityPoolDepositorLQTYGain;
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

    // Module
    LiquityDepositModule public liquityDepositModule;

    // Global
    uint256 public constant mplGlobalLpCooldownPeriod = 864000;
    uint256 public constant mplGlobalLpWithdrawWindow = 172800;
    uint256 public moduleDelay;
    address public stakingToken = 0x5f98805A4E8be255a32880FDeC7F6728C6568bA0; // LUSD
    address rewardToken = 0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D; // LQTY

    function setUp() public {
        // Liquity module
        vm.prank(owner);
        liquityDepositModule = new LiquityDepositModule(
            address(moduleManager),
            address(lusd),
            address(pho)
        );

        // Add module to ModuleManager
        vm.startPrank(PHOGovernance);
        moduleManager.addModule(address(liquityDepositModule));
        vm.stopPrank();

        // Increase PHO ceilings for modules
        vm.startPrank(TONGovernance);
        moduleManager.setPHOCeilingForModule(address(liquityDepositModule), ONE_MILLION_D18);
        vm.stopPrank();

        moduleDelay = moduleManager.moduleDelay();

        vm.warp(block.timestamp + moduleDelay);

        moduleManager.executeCeilingUpdate(address(liquityDepositModule));

        // Fund users 1 & 2 with LUSD
        vm.startPrank(lusdWhale);
        lusd.transfer(user1, TEN_THOUSAND_D18);
        lusd.transfer(user2, TEN_THOUSAND_D18);

        // Also fund module with some LUSD
        lusd.approve(liquityDepositModule.liquityModuleAMO(), TEN_THOUSAND_D18);
        lusd.transfer(liquityDepositModule.liquityModuleAMO(), TEN_THOUSAND_D18);
        vm.stopPrank();

        // Mint PHO to users 1 & 2
        vm.prank(address(moduleManager));
        kernel.mintPHO(address(user1), ONE_HUNDRED_D18);
        vm.prank(address(moduleManager));
        kernel.mintPHO(address(user2), ONE_HUNDRED_D18);

        // Approve sending LUSD to LiquityDeposit contract - user 1
        vm.startPrank(user1);
        lusd.approve(address(liquityDepositModule), TEN_THOUSAND_D18);

        // Do same for liquity AMO
        lusd.approve(address(liquityDepositModule.liquityModuleAMO()), TEN_THOUSAND_D18);

        // Allow sending PHO (redemptions) to LiquityDeposit contracts
        pho.approve(address(liquityDepositModule), TEN_THOUSAND_D18);

        // Approve PHO burnFrom() via moduleManager calling kernel
        pho.approve(address(kernel), ONE_MILLION_D18);
        vm.stopPrank();

        // Approve sending LUSD to LiquityDeposit contract - user 2
        vm.startPrank(user2);
        lusd.approve(address(liquityDepositModule), TEN_THOUSAND_D18);

        // Do same for liquity AMO
        lusd.approve(address(liquityDepositModule.liquityModuleAMO()), TEN_THOUSAND_D18);

        // Allow sending PHO (redemptions) to LiquityDeposit contracts
        pho.approve(address(liquityDepositModule), TEN_THOUSAND_D18);

        // Approve PHO burnFrom() via moduleManager calling kernel
        pho.approve(address(kernel), ONE_MILLION_D18);
        vm.stopPrank();

        // Allow sending PHO (redemptions) to LiquityDeposit contracts
        pho.approve(address(liquityDepositModule), TEN_THOUSAND_D18);

        // Approve PHO burnFrom() via moduleManager calling kernel
        pho.approve(address(kernel), ONE_MILLION_D18);
        vm.stopPrank();
    }

    // Cannot set any 0 addresses for constructor
    function testCannotMakeLiquityDepositModuleWithZeroAddress() public {
        vm.startPrank(user1);

        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        liquityDepositModule = new LiquityDepositModule(
            address(0),
            address(lusd),
            address(pho)
        );

        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        liquityDepositModule = new LiquityDepositModule(
            address(moduleManager),
            address(0),
            address(pho)
        );

        vm.expectRevert(abi.encodeWithSelector(ZeroAddressDetected.selector));
        liquityDepositModule = new LiquityDepositModule(
            address(moduleManager),
            address(lusd),
            address(0)
        );

        vm.stopPrank();
    }

    // Cannot deposit 0
    function testCannotDepositZero() public {
        uint256 depositAmount = 0;
        vm.expectRevert(abi.encodeWithSelector(CannotDepositZero.selector));
        vm.prank(user1);
        liquityDepositModule.deposit(depositAmount);
    }

    // Test basic deposit
    function testDepositLiquityModule() public {
        uint256 depositAmount = ONE_HUNDRED_D18;
        _testDepositAnyModule(depositAmount, liquityDepositModule);
    }

    // Helper function to test Liquity deposit from any module
    function _testDepositAnyModule(uint256 _depositAmount, LiquityDepositModule _module) public {
        // Convert expected issue amount based on stablecoin decimals
        uint256 scaledDepositAmount = _depositAmount;

        uint256 expectedIssuedAmount = scaledDepositAmount;

        address moduleRewardPool = _module.liquityModuleAMO();

        // LUSD and PHO balances before
        LiquityBalance memory before;
        before.userStablecoinBalance = lusd.balanceOf(address(user1));
        before.moduleStablecoinBalance = lusd.balanceOf(address(_module));
        before.userPHOBalance = pho.balanceOf(user1);
        before.userIssuedAmount = _module.issuedAmount(user1);
        before.userStakedAmount = LiquityModuleAMO(moduleRewardPool).stakedAmount(user1);
        before.totalPHOSupply = pho.totalSupply();

        // Check stability pool
        before.liquityPoolDeposits =
            _module.stabilityPool().getCompoundedLUSDDeposit(moduleRewardPool);
        before.liquityPoolDepositorLQTYGain =
            _module.stabilityPool().getDepositorLQTYGain(moduleRewardPool);

        // Deposit
        vm.expectEmit(true, true, true, true);
        emit Deposited(user1, _depositAmount, expectedIssuedAmount);
        vm.prank(user1);
        _module.deposit(_depositAmount);

        // DepositToken and PHO balances after
        LiquityBalance memory aft;
        aft.userStablecoinBalance = lusd.balanceOf(address(user1));
        aft.moduleStablecoinBalance = lusd.balanceOf(address(_module));
        aft.userPHOBalance = pho.balanceOf(user1);
        aft.userIssuedAmount = _module.issuedAmount(user1);
        aft.userStakedAmount = LiquityModuleAMO(moduleRewardPool).stakedAmount(user1);
        aft.totalPHOSupply = pho.totalSupply();

        // Check stability pool
        aft.liquityPoolDeposits = _module.stabilityPool().getCompoundedLUSDDeposit(moduleRewardPool);
        aft.liquityPoolDepositorLQTYGain =
            _module.stabilityPool().getDepositorLQTYGain(moduleRewardPool);

        // User balance - depositToken down and PHO up
        assertEq(aft.userStablecoinBalance + _depositAmount, before.userStablecoinBalance);
        assertEq(aft.userPHOBalance, before.userPHOBalance + expectedIssuedAmount);

        // Deposit module balance - depositToken same (goes to Liquity pool)
        assertEq(aft.moduleStablecoinBalance, before.moduleStablecoinBalance);

        // Check issued amount goes up
        assertEq(aft.userIssuedAmount, before.userIssuedAmount + expectedIssuedAmount);

        // Check staked amount goes up
        assertEq(aft.userStakedAmount, before.userStakedAmount + scaledDepositAmount);

        // Check PHO total supply goes up
        assertEq(aft.totalPHOSupply, before.totalPHOSupply + expectedIssuedAmount);

        // Check Liquity pool balance goes up
        assertEq(aft.liquityPoolDeposits, before.liquityPoolDeposits + scaledDepositAmount);

        // Check Liquity pool LQTY gain is same as before
        assertEq(aft.liquityPoolDepositorLQTYGain, before.liquityPoolDepositorLQTYGain);
    }

    // Cannot redeem 0
    function testCannotRedeemZero() public {
        vm.expectRevert(abi.encodeWithSelector(CannotRedeemZeroTokens.selector));
        vm.prank(user1);
        liquityDepositModule.redeem();
    }

    // Test Redeem
    function testRedeemLiquityModule() public {
        uint256 depositAmount = ONE_HUNDRED_D18;
        uint256 redeemAmount = ONE_HUNDRED_D18;
        uint256 withdrawTimestamp = block.timestamp + 10000;
        _testDepositAnyModule(depositAmount, liquityDepositModule);
        _testRedeemAnyModule(redeemAmount, liquityDepositModule, withdrawTimestamp);
    }

    // Helper function to test Liquity redeem from any module
    function _testRedeemAnyModule(
        uint256 _redeemAmount,
        LiquityDepositModule _module,
        uint256 withdrawTimestamp
    ) public {
        // Convert expected issue amount based on stablecoin decimals
        uint256 scaledRedeemAmount = _redeemAmount;

        uint256 expectedRedeemAmount = scaledRedeemAmount;

        address moduleRewardPool = _module.liquityModuleAMO();

        // LUSD and PHO balances before
        LiquityBalance memory before;
        before.userStablecoinBalance = lusd.balanceOf(address(user1));
        before.moduleStablecoinBalance = lusd.balanceOf(address(_module));
        before.userPHOBalance = pho.balanceOf(user1);
        before.userIssuedAmount = _module.issuedAmount(user1);
        before.userStakedAmount = LiquityModuleAMO(moduleRewardPool).stakedAmount(user1);
        before.totalPHOSupply = pho.totalSupply();

        // Check stability pool
        before.liquityPoolDeposits =
            _module.stabilityPool().getCompoundedLUSDDeposit(moduleRewardPool);
        before.liquityPoolDepositorLQTYGain =
            _module.stabilityPool().getDepositorLQTYGain(moduleRewardPool);

        // Redeem
        vm.warp(withdrawTimestamp);
        vm.expectEmit(true, true, true, true);
        emit Redeemed(user1, before.userIssuedAmount);
        vm.prank(user1);
        _module.redeem();

        // DepositToken and PHO balances after
        LiquityBalance memory aft;
        aft.userStablecoinBalance = lusd.balanceOf(address(user1));
        aft.moduleStablecoinBalance = lusd.balanceOf(address(_module));
        aft.userPHOBalance = pho.balanceOf(user1);
        aft.userIssuedAmount = _module.issuedAmount(user1);
        aft.userStakedAmount = LiquityModuleAMO(moduleRewardPool).stakedAmount(user1);
        aft.totalPHOSupply = pho.totalSupply();

        // Check stability pool
        aft.liquityPoolDeposits = _module.stabilityPool().getCompoundedLUSDDeposit(moduleRewardPool);
        aft.liquityPoolDepositorLQTYGain =
            _module.stabilityPool().getDepositorLQTYGain(moduleRewardPool);

        // User balance - depositToken up and PHO down
        assertEq(aft.userStablecoinBalance, before.userStablecoinBalance + _redeemAmount);
        assertEq(aft.userPHOBalance + expectedRedeemAmount, before.userPHOBalance);

        // // Deposit module balance - depositToken same (goes to Liquity pool)
        assertEq(aft.moduleStablecoinBalance, before.moduleStablecoinBalance);

        // Check issued amount goes down
        assertEq(aft.userIssuedAmount + expectedRedeemAmount, before.userIssuedAmount);

        // Check staked amount goes down
        assertEq(aft.userStakedAmount + scaledRedeemAmount, before.userStakedAmount);

        // Check PHO total supply goes down
        assertEq(aft.totalPHOSupply + expectedRedeemAmount, before.totalPHOSupply);

        // Check Liquity pool balance goes down
        assertEq(aft.liquityPoolDeposits + scaledRedeemAmount, before.liquityPoolDeposits);

        // Check Liquity pool LQTY gain is same as before
        assertEq(aft.liquityPoolDepositorLQTYGain, before.liquityPoolDepositorLQTYGain);
    }

    // Test Reward
    function testRewardLiquityModule() public {
        uint256 depositAmount = ONE_HUNDRED_D18;
        _testGetRewardAnyModule(depositAmount, liquityDepositModule);
    }

    // Helper function to test Liquity rewards from any module
    function _testGetRewardAnyModule(uint256 _depositAmount, LiquityDepositModule _module) public {
        address moduleRewardPool = _module.liquityModuleAMO();

        vm.prank(user1);
        _module.deposit(_depositAmount);

        // Advance days to accrue rewards
        vm.warp(block.timestamp + 7 days);

        // Get reward
        vm.prank(owner);
        uint256 rewardsLiquity = LiquityModuleAMO(moduleRewardPool).getRewardLiquity();

        // User gets the reward
        vm.warp(block.timestamp + 1 days);

        vm.prank(user1);
        LiquityModuleAMO(moduleRewardPool).getReward(user1);

        uint256 finalUserRewardsBalance =
            IERC20(LiquityModuleAMO(moduleRewardPool).rewardToken()).balanceOf(user1);

        // Check that user got rewards and protocol has none
        assertTrue(finalUserRewardsBalance > 0);
    }

    // Testing shares

    // Test basic shares for deposit - USDC
    function testSharesDepositLiquityModule() public {
        uint256 depositAmount = ONE_HUNDRED_D18;
        _testSharesDepositAnyModule(depositAmount, address(lusd), liquityDepositModule);
    }

    // Helper function to test shares for Liquity deposit from any module
    function _testSharesDepositAnyModule(
        uint256 _depositAmount,
        address _depositToken,
        LiquityDepositModule _module
    ) public {
        LiquityModuleAMO amo = LiquityModuleAMO(_module.liquityModuleAMO());

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

    // Test Redeem
    function testSharesRedeemLiquityModule() public {
        uint256 depositAmount = ONE_HUNDRED_D18;
        uint256 redeemAmount = ONE_HUNDRED_D18;
        uint256 withdrawTimestamp = block.timestamp + 10 days;
        _testSharesDepositAnyModule(depositAmount, address(lusd), liquityDepositModule);
        uint256 startingTotalDeposits = depositAmount + depositAmount / 4;
        uint256 startingTotalShares = depositAmount + depositAmount / 5;
        _testSharesRedeemAnyModule(
            redeemAmount,
            address(lusd),
            liquityDepositModule,
            withdrawTimestamp,
            startingTotalDeposits,
            startingTotalShares
        );
    }

    // Helper function to test shares for Liquity redeem from any module
    function _testSharesRedeemAnyModule(
        uint256 _redeemAmount,
        address _depositToken,
        LiquityDepositModule _module,
        uint256 withdrawTimestamp,
        uint256 _startingTotalDeposits,
        uint256 _startingTotalShares
    ) public {
        // Convert expected issue amount based on stablecoin decimals
        address moduleRewardPool = _module.liquityModuleAMO();

        LiquityModuleAMO amo = LiquityModuleAMO(_module.liquityModuleAMO());

        // Shares tracking before - users 1 & 2
        SharesVars memory before1;
        before1.shares = amo.sharesOf(user1);
        before1.earned = amo.earned(user1);
        before1.totalShares = amo.totalShares();
        SharesVars memory before2;
        before2.shares = amo.sharesOf(user2);
        before2.earned = amo.earned(user2);
        before2.totalShares = amo.totalShares();

        vm.warp(withdrawTimestamp);

        // Redeem for user 1
        vm.warp(withdrawTimestamp);
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
    function testSharesRewardLiquityModule() public {
        uint256 depositAmount = ONE_HUNDRED_D18;
        _testSharesGetRewardAnyModule(depositAmount, liquityDepositModule);
    }

    // Helper function to test Liquity rewards from any module
    function _testSharesGetRewardAnyModule(uint256 _depositAmount, LiquityDepositModule _module)
        public
    {
        address moduleRewardPool = _module.liquityModuleAMO();

        LiquityModuleAMO amo = LiquityModuleAMO(_module.liquityModuleAMO());

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
        vm.warp(block.timestamp + 10 days);

        // Get reward
        vm.prank(owner);
        uint256 rewardsLiquity = amo.getRewardLiquity();

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
        assertApproxEqAbs(aft1.earned, 5 * aft2.earned, 1000 wei);

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
