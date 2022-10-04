// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "./BaseSetup.t.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/contracts/BondBaseDispatcher.sol";
import "src/contracts/BondFixedExpiryDispatcher.sol";
import "src/contracts/BondFixedExpiryModule.sol";
import "src/contracts/BondBaseModule.sol";
import "src/interfaces/IBondModule.sol";

contract BondModuleTest is BaseSetup {
    // Contract relevant test constants
    address public protocol = 0xe688b84b23f322a994A53dbF8E15FA82CDB71127;
    BondFixedExpiryModule public bondFixedExpiryModule;

    // Structs
    struct MarketParams {
        ERC20 payoutToken; // payout token
        ERC20 quoteToken; // quote token
        uint256 capacity; // capacity
        uint256 formattedInitialPrice; // initial price
        uint256 formattedMinimumPrice; // min price
        uint48 vesting; // if fixed term then vesting length otherwise vesting expiry timestamp
        uint48 conclusion; // conclusion timestamp
        uint32 depositInterval; // deposit interval
        int8 scaleAdjustment; // scale adjustment
    }

    struct BondMetadata {
        uint48 lastTune; // last timestamp when control variable was tuned
        uint48 lastDecay; // last timestamp when market was created and debt was decayed
        uint32 length; // time from creation to conclusion
        uint32 depositInterval; // target frequency of deposits
        uint32 tuneInterval; // frequency of tuning
        uint32 tuneAdjustmentDelay; // time to implement downward tuning adjustments
        uint32 debtDecayInterval; // interval over which debt should decay completely
        uint256 tuneIntervalCapacity; // capacity expected to be used during a tuning interval
        uint256 tuneBelowCapacity; // capacity that the next tuning will occur at
        uint256 lastTuneDebt; // target debt calculated at last tuning
    }

    struct BondMarket {
        ERC20 payoutToken; // payout token that bonders receive - PHO or TON
        ERC20 quoteToken; // quote token that bonders deposit
        uint256 capacity; // capacity remaining - in terms of payout token
        uint256 totalDebt; // total payout token debt from market
        uint256 minPrice; // minimum price (debt will stop decaying to maintain this)
        uint256 maxPayout; // max payout tokens out in one order
        uint256 sold; // payout tokens out
        uint256 purchased; // quote tokens in
        uint256 scale; // scaling factor for the market (see MarketParams struct)
    }

    struct BondTerms {
        uint256 controlVariable; // scaling variable for price
        uint256 maxDebt; // max payout token debt accrued
        uint48 vesting; // length of time from deposit to expiry if fixed-term, vesting timestamp if fixed-expiry
        uint48 conclusion; // timestamp when market no longer offered
    }

    // State vars
    uint32 public defaultTuneInterval; // tune interval
    uint32 public defaultTuneAdjustment; // tune adjustment
    uint32 public minDebtDecayInterval; // decay
    uint32 public minDepositInterval; // deposit interval
    uint32 public minMarketDuration; // market duration
    uint32 public minDebtBuffer; // debt buffer

    uint48 internal constant FEE_DECIMALS = 10 ** 5;

    function setUp() public {
        vm.prank(owner);
        bondFixedExpiryModule = new BondFixedExpiryModule(
            controller,
            address(pho),
            address(ton),
            protocol
        );
        defaultTuneInterval = 24 hours;
        defaultTuneAdjustment = 1 hours;
        minDebtDecayInterval = 3 days;
        minDepositInterval = 1 hours;
        minMarketDuration = 1 days;
        minDebtBuffer = 10000; // 10%

        // User -> sends USDC to dispatcher (who sends to controller)
        // Bond controller sends PHO to dispatcher
        vm.prank(owner);
        teller.whitelistCaller(address(bondFixedExpiryModule), 200 * TEN_THOUSAND_D18);
        vm.prank(address(bondFixedExpiryModule));
        teller.mintPHO(address(bondFixedExpiryModule), TEN_THOUSAND_D18);

        // User1 gets TON and approves sending to BondDispatcher
        _getTON(user1, TEN_THOUSAND_D18);
        vm.prank(user1);
        ton.approve(address(bondFixedExpiryModule), 100 * TEN_THOUSAND_D18);

        // Approval for bondController sending PHO to BondDispatcher
        vm.prank(address(bondFixedExpiryModule));
        pho.approve(address(bondFixedExpiryModule), 100 * TEN_THOUSAND_D18);
    }

    /// Creating BondModule

    // Cannot create BondModule with zero address
    function testCannotCreateBondModuleZeroAddress() public {
        vm.expectRevert("BondModule: zero address detected");
        vm.prank(owner);
        bondFixedExpiryModule = new BondFixedExpiryModule(
            address(bondFixedExpiryModule),
            address(0),
            address(pho),
            address(ton)
        );

        vm.expectRevert("BondModule: zero address detected");
        vm.prank(owner);
        bondFixedExpiryModule = new BondFixedExpiryModule(
            address(bondFixedExpiryModule),
            address(controller),
            address(0),
            address(ton)
        );

        vm.expectRevert("BondModule: zero address detected");
        vm.prank(owner);
        bondFixedExpiryModule = new BondFixedExpiryModule(
            address(bondFixedExpiryModule),
            address(controller),
            address(pho),
            address(0)
        );
    }

    /// createMarket()

    // Cannot create if not owner/controller
    function testCannotCreateMarketOnlyOwnerModule() public {
        MarketParams memory params = MarketParams({
            payoutToken: pho,
            quoteToken: ton,
            capacity: 10 ** 18,
            formattedInitialPrice: 10 ** 6,
            formattedMinimumPrice: 10 ** 4,
            vesting: 1000000000,
            conclusion: 10000000000,
            depositInterval: 1000000,
            scaleAdjustment: 10
        });
        vm.expectRevert("BondModule: not the owner or controller");
        vm.prank(user1);
        bondFixedExpiryModule.createMarket(abi.encode(params));
    }

    // Cannot use invalid params for createMarket()
    function testCannotCreateMarketInvalidParams() public {
        // payout token not PHO or TON
        MarketParams memory params = MarketParams({
            payoutToken: ERC20(address(fraxBPLP)),
            quoteToken: ton,
            capacity: 10 ** 18,
            formattedInitialPrice: 10 ** 6,
            formattedMinimumPrice: 10 ** 4,
            vesting: 1000000000,
            conclusion: 10000000000,
            depositInterval: 24 hours,
            scaleAdjustment: 30
        });
        vm.expectRevert("BondModule: payoutToken must be PHO or TON");
        vm.prank(owner);
        bondFixedExpiryModule.createMarket(abi.encode(params));

        // scaleAdjustment too high
        params = MarketParams({
            payoutToken: pho,
            quoteToken: ton,
            capacity: 10 ** 18,
            formattedInitialPrice: 10 ** 6,
            formattedMinimumPrice: 10 ** 4,
            vesting: 1000000000,
            conclusion: 10000000000,
            depositInterval: 24 hours,
            scaleAdjustment: 30
        });
        vm.expectRevert("BondModule: createMarket invalid params");
        vm.prank(owner);
        bondFixedExpiryModule.createMarket(abi.encode(params));

        // formattedInitialPrice < formattedMinimumPrice
        params = MarketParams({
            payoutToken: pho,
            quoteToken: ton,
            capacity: 10 ** 18,
            formattedInitialPrice: 10 ** 4,
            formattedMinimumPrice: 10 ** 5,
            vesting: 1000000000,
            conclusion: 10000000000,
            depositInterval: 24 hours,
            scaleAdjustment: 30
        });
        vm.expectRevert("BondModule: createMarket invalid params");
        vm.prank(owner);
        bondFixedExpiryModule.createMarket(abi.encode(params));

        // params.conclusion - block.timestamp < minMarketDuration
        params = MarketParams({
            payoutToken: pho,
            quoteToken: ton,
            capacity: 10 ** 18,
            formattedInitialPrice: 10 ** 4,
            formattedMinimumPrice: 10 ** 5,
            vesting: 1000000000,
            conclusion: uint48(block.timestamp) + 1 days - 1,
            depositInterval: 24 hours,
            scaleAdjustment: 30
        });
        vm.expectRevert("BondModule: createMarket invalid params");
        vm.prank(owner);
        bondFixedExpiryModule.createMarket(abi.encode(params));

        // depositInterval < minDepositInterval
        params = MarketParams({
            payoutToken: pho,
            quoteToken: ton,
            capacity: 10 ** 18,
            formattedInitialPrice: 10 ** 4,
            formattedMinimumPrice: 10 ** 5,
            vesting: 1000000000,
            conclusion: 10000000000,
            depositInterval: 1 hours - 1,
            scaleAdjustment: 30
        });
        vm.expectRevert("BondModule: createMarket invalid params");
        vm.prank(owner);
        bondFixedExpiryModule.createMarket(abi.encode(params));
    }

    // Test basic createMarket, checking BondMetadata struct
    function testCreateMarketBasicBondMetadata() public {
        MarketParams memory params = MarketParams({
            payoutToken: pho,
            quoteToken: ton,
            capacity: 10 ** 18,
            formattedInitialPrice: 10 ** 6,
            formattedMinimumPrice: 10 ** 4,
            vesting: 1000000000,
            conclusion: 10000000000,
            depositInterval: 24 hours,
            scaleAdjustment: 10
        });
        vm.prank(owner);
        bondFixedExpiryModule.createMarket(abi.encode(params));

        // check BondMetadata
        (
            uint48 lastTune,
            uint48 lastDecay,
            uint32 length,
            uint32 depositInterval,
            uint32 tuneInterval,
            uint32 tuneAdjustmentDelay,
            uint32 debtDecayInterval,
            uint256 tuneIntervalCapacity,
            uint256 tuneBelowCapacity,
            uint256 lastTuneDebt
        ) = bondFixedExpiryModule.metadata(0);

        uint256 currentTuneIntervalCapacity = (params.capacity * params.depositInterval)
            / uint256(params.conclusion - block.timestamp);

        uint256 currentLastTuneDebt = ((params.capacity) * uint256(debtDecayInterval))
            / uint256(params.conclusion - block.timestamp);

        assertEq(lastTune, uint48(block.timestamp));
        assertEq(lastDecay, uint48(block.timestamp));
        assertEq(length, uint32(params.conclusion - block.timestamp));
        assertEq(depositInterval, params.depositInterval);
        assertEq(tuneInterval, defaultTuneInterval);
        assertEq(tuneAdjustmentDelay, defaultTuneAdjustment);
        assertEq(debtDecayInterval, minDebtDecayInterval);
        assertEq(tuneIntervalCapacity, currentTuneIntervalCapacity);
        assertEq(tuneBelowCapacity, params.capacity - currentTuneIntervalCapacity);
        assertEq(lastTuneDebt, currentLastTuneDebt);
    }

    // Test basic createMarket, checking BondMarket struct
    function testCreateMarketBasicBondMarket() public {
        MarketParams memory params = MarketParams({
            payoutToken: pho,
            quoteToken: ton,
            capacity: 10 ** 18,
            formattedInitialPrice: 10 ** 6,
            formattedMinimumPrice: 10 ** 4,
            vesting: 1000000000,
            conclusion: 10000000000,
            depositInterval: 24 hours,
            scaleAdjustment: 10
        });
        vm.prank(owner);
        bondFixedExpiryModule.createMarket(abi.encode(params));

        // Bond market
        uint256 targetDebt = (params.capacity * uint256(minDebtDecayInterval))
            / (uint256(params.conclusion - block.timestamp));

        // max payout = capacity / deposit interval, i.e. 1000 TOK of capacity / 10 days = 100 TOK max
        uint256 currentMaxPayout = (params.capacity * uint256(params.depositInterval))
            / uint256(params.conclusion - block.timestamp);

        uint256 currentScale = 10 ** uint8(36 + params.scaleAdjustment);

        (
            ERC20 payoutToken,
            ERC20 quoteToken,
            uint256 capacity,
            uint256 totalDebt,
            uint256 minPrice,
            uint256 maxPayout,
            uint256 sold,
            uint256 purchased,
            uint256 scale
        ) = bondFixedExpiryModule.markets(0);

        assertEq(address(payoutToken), address(pho));
        assertEq(address(quoteToken), address(ton));
        assertEq(capacity, params.capacity);
        assertEq(totalDebt, targetDebt);
        assertEq(minPrice, params.formattedMinimumPrice);
        assertEq(maxPayout, currentMaxPayout);
        assertEq(purchased, 0);
        assertEq(sold, 0);
        assertEq(scale, currentScale);
    }

    // Test basic createMarket, checking BondTerms struct
    function testCreateMarketBasicBondTerms() public {
        MarketParams memory params = MarketParams({
            payoutToken: pho,
            quoteToken: ton,
            capacity: 10 ** 18,
            formattedInitialPrice: 10 ** 6,
            formattedMinimumPrice: 10 ** 4,
            vesting: 1000000000,
            conclusion: 10000000000,
            depositInterval: 24 hours,
            scaleAdjustment: 10
        });
        vm.prank(owner);
        bondFixedExpiryModule.createMarket(abi.encode(params));

        // From prev
        uint256 targetDebt = (params.capacity * uint256(minDebtDecayInterval))
            / (uint256(params.conclusion - block.timestamp));

        uint256 currentScale = 10 ** uint8(36 + params.scaleAdjustment);

        uint256 currentMaxDebt = targetDebt + ((targetDebt * minDebtBuffer) / FEE_DECIMALS);
        uint256 currentControlVariable = (params.formattedInitialPrice * currentScale) / targetDebt;
        // Bond terms
        (uint256 controlVariable, uint256 maxDebt, uint48 vesting, uint48 conclusion) =
            bondFixedExpiryModule.terms(0);
        assertEq(controlVariable, currentControlVariable);
        assertEq(maxDebt, currentMaxDebt);
        assertEq(vesting, params.vesting);
        assertEq(conclusion, params.conclusion);
    }

    /// Setting intervals

    // Cannot set intervals if not owner/controller
    function testCannotSetIntervalsOnlyOwnerModule() public {
        uint32[] memory intervals = new uint32[](3);
        intervals[0] = 0;
        intervals[1] = 1;
        intervals[2] = 2;
        vm.expectRevert("BondModule: not the owner or controller");
        vm.prank(user1);
        bondFixedExpiryModule.setIntervals(0, intervals);
    }

    // Cannot set intervals to have any 0 or [0] < [1]
    function testCannotSetIntervalsInvalidParams() public {
        uint32[] memory intervals = new uint32[](3);
        intervals[0] = 0;
        intervals[1] = 1;
        intervals[2] = 2;

        // intervals[0] = 0
        vm.expectRevert("BondModule: setIntervals invalid params");
        vm.prank(owner);
        bondFixedExpiryModule.setIntervals(0, intervals);

        intervals[0] = 1;
        intervals[1] = 0;

        // intervals[1] = 0
        vm.expectRevert("BondModule: setIntervals invalid params");
        vm.prank(owner);
        bondFixedExpiryModule.setIntervals(0, intervals);

        intervals[1] = 2;
        intervals[2] = 0;

        // intervals[2] = 0
        vm.expectRevert("BondModule: setIntervals invalid params");
        vm.prank(owner);
        bondFixedExpiryModule.setIntervals(0, intervals);

        intervals[0] = 1;
        intervals[1] = 2;

        // intervals[0] < intervals[1]
        vm.expectRevert("BondModule: setIntervals invalid params");
        vm.prank(owner);
        bondFixedExpiryModule.setIntervals(0, intervals);
    }

    // Basic setIntervals
    function testSetIntervals() public {
        MarketParams memory params = MarketParams({
            payoutToken: pho,
            quoteToken: ton,
            capacity: 10 ** 18,
            formattedInitialPrice: 10 ** 6,
            formattedMinimumPrice: 10 ** 4,
            vesting: 1000000000,
            conclusion: 10000000000,
            depositInterval: 24 hours,
            scaleAdjustment: 10
        });
        vm.prank(owner);
        bondFixedExpiryModule.createMarket(abi.encode(params));

        uint32[] memory intervals = new uint32[](3);
        intervals[0] = 48 hours;
        intervals[1] = 2 hours;
        intervals[2] = 4 days;

        // intervals[0] = 0
        vm.prank(owner);
        bondFixedExpiryModule.setIntervals(0, intervals);

        (
            uint48 lastTune,
            uint48 lastDecay,
            uint32 length,
            uint32 depositInterval,
            uint32 tuneInterval,
            uint32 tuneAdjustmentDelay,
            uint32 debtDecayInterval,
            uint256 tuneIntervalCapacity,
            uint256 tuneBelowCapacity,
            uint256 lastTuneDebt
        ) = bondFixedExpiryModule.metadata(0);

        uint256 currentTuneIntervalCapacity =
            (10 ** 18 * uint256(intervals[0])) / uint256(10000000000 - block.timestamp);

        assertEq(tuneInterval, intervals[0]);
        assertEq(tuneIntervalCapacity, currentTuneIntervalCapacity);
        assertEq(tuneAdjustmentDelay, intervals[1]);
        assertEq(debtDecayInterval, intervals[2]);
    }

    /// Set defaults

    // Cannot setDefaults if not owner/controller
    function testCannotSetDefaultsOnlyOwnerModule() public {
        uint32[] memory defaults = new uint32[](6);
        defaults[0] = 48 hours;
        defaults[1] = 2 hours;
        defaults[2] = 6 days;
        defaults[3] = 2 hours;
        defaults[4] = 2 days;
        defaults[5] = 20000;

        vm.expectRevert("BondModule: not the owner or controller");
        vm.prank(user1);
        bondFixedExpiryModule.setDefaults(defaults);
    }

    // Basic setDefaults
    function testSetDefaults() public {
        uint32[] memory defaults = new uint32[](6);
        defaults[0] = 48 hours;
        defaults[1] = 2 hours;
        defaults[2] = 6 days;
        defaults[3] = 2 hours;
        defaults[4] = 2 days;
        defaults[5] = 20000;

        vm.prank(owner);
        bondFixedExpiryModule.setDefaults(defaults);

        assertEq(bondFixedExpiryModule.defaultTuneInterval(), defaults[0]);
        assertEq(bondFixedExpiryModule.defaultTuneAdjustment(), defaults[1]);
        assertEq(bondFixedExpiryModule.minDebtDecayInterval(), defaults[2]);
        assertEq(bondFixedExpiryModule.minDepositInterval(), defaults[3]);
        assertEq(bondFixedExpiryModule.minMarketDuration(), defaults[4]);
        assertEq(bondFixedExpiryModule.minDebtBuffer(), defaults[5]);
    }

    /// Close market

    // Cannot closeMarket if not owner/controller
    function testCannotCloseMarketOnlyOwnerModule() public {
        vm.expectRevert("BondModule: not the owner or controller");
        vm.prank(user1);
        bondFixedExpiryModule.closeMarket(0);
    }

    // Basic setDefaults
    function testCloseMarket() public {
        MarketParams memory params = MarketParams({
            payoutToken: pho,
            quoteToken: ton,
            capacity: 10 ** 18,
            formattedInitialPrice: 10 ** 6,
            formattedMinimumPrice: 10 ** 4,
            vesting: 1000000000,
            conclusion: 10000000000,
            depositInterval: 24 hours,
            scaleAdjustment: 10
        });
        vm.prank(owner);
        bondFixedExpiryModule.createMarket(abi.encode(params));

        vm.prank(owner);
        bondFixedExpiryModule.closeMarket(0);

        (,,, uint48 conclusion) = bondFixedExpiryModule.terms(0);
        (,, uint256 capacity,,,,,,) = bondFixedExpiryModule.markets(0);

        assertEq(conclusion, uint48(block.timestamp));
        assertEq(capacity, 0);
    }

    // Purchase bond

    // Cannot purchase bond if past conclusion
    function testCannotPurchaseBondAfterConclusion() public {
        uint256 amount = 100000;
        uint256 minAmountOut = 50000;
        MarketParams memory params = MarketParams({
            payoutToken: pho,
            quoteToken: ton,
            capacity: 10 ** 18,
            formattedInitialPrice: 10 ** 6,
            formattedMinimumPrice: 10 ** 4,
            vesting: 1000000000,
            conclusion: uint48(block.timestamp + 2 days),
            depositInterval: 24 hours,
            scaleAdjustment: 10
        });
        vm.prank(owner);
        bondFixedExpiryModule.createMarket(abi.encode(params));

        vm.warp(block.timestamp + 2 days + 1);

        vm.expectRevert("BondModule: purchaseBond window passed");
        vm.prank(address(bondFixedExpiryModule));
        bondFixedExpiryModule.purchaseBond(0, amount, minAmountOut);
    }

    /// Basic purchaseBond
    function testPurchaseBondBasic() public {
        uint256 amount = 100000;
        uint256 minAmountOut = 50000;
        MarketParams memory params = MarketParams({
            payoutToken: pho,
            quoteToken: ton,
            capacity: 10 ** 18,
            formattedInitialPrice: 10 ** 6,
            formattedMinimumPrice: 10 ** 4,
            vesting: 1000000000,
            conclusion: 10000000000,
            depositInterval: 24 hours,
            scaleAdjustment: 10
        });
        vm.prank(owner);
        bondFixedExpiryModule.createMarket(abi.encode(params));

        uint256 targetDebt = (params.capacity * uint256(minDebtDecayInterval))
            / (uint256(params.conclusion - block.timestamp));

        vm.prank(address(bondFixedExpiryModule));
        bondFixedExpiryModule.purchaseBond(0, amount, minAmountOut);

        (,, uint256 capacity, uint256 totalDebt,,, uint256 sold, uint256 purchased,) =
            bondFixedExpiryModule.markets(0);

        assertEq(capacity, 10 ** 18 - amount);
        assertEq(totalDebt, targetDebt + amount + 1);
        assertEq(purchased, amount);
        assertEq(sold, amount);
    }

    /// Dispatcher side

    /// Setting protocol fees

    // Cannot set protocol fee if not owner/controller
    function testCannotSetProtocolFeeOnlyOwnerController() public {
        uint48 newFee = 500;
        vm.expectRevert("BondModule: not the owner or controller");
        vm.prank(user1);
        bondFixedExpiryModule.setProtocolFee(newFee);
    }

    // Basic set protocol fee
    function testSetProtocolFee() public {
        uint48 newFee = 500;
        vm.prank(owner);
        bondFixedExpiryModule.setProtocolFee(newFee);
        assertEq(bondFixedExpiryModule.protocolFee(), newFee);
    }

    /// Registering market

    // Cannot register market if not owner/controller
    function testCannotRegisterMarketOnlyOwnerController() public {
        address newBondController = 0xDAFEA492D9c6733ae3d56b7Ed1ADB60692c98Bc5;
        vm.expectRevert("BondModule: not the owner or controller");
        vm.prank(user1);
        bondFixedExpiryModule.registerMarket(ERC20(pho), ERC20(ton));
    }

    // Basic set register market
    function testRegisterMarket() public {
        vm.prank(owner);
        bondFixedExpiryModule.registerMarket(ERC20(pho), ERC20(ton));
        assertEq(bondFixedExpiryModule.marketCounter(), 1);
        assertEq(bondFixedExpiryModule.marketsForPayout(address(pho), 0), 0);
        assertEq(bondFixedExpiryModule.marketsForQuote(address(ton), 0), 0);
    }

    /// Claim fees

    // Cannot claim fees if not owner/controller
    function testCannotClaimFeesOnlyOwnerController() public {
        ERC20[] memory tokens = new ERC20[](1);
        tokens[0] = pho;
        vm.expectRevert("BondModule: not the owner or controller");
        vm.prank(user1);
        bondFixedExpiryModule.claimFees(tokens, user1);
    }

    // Basic claim of 0 fees
    function testClaimZeroFees() public {
        ERC20[] memory tokens = new ERC20[](1);
        tokens[0] = pho;
        uint256 phoBalanceOwnerBefore = pho.balanceOf(address(owner));
        vm.prank(owner);
        bondFixedExpiryModule.claimFees(tokens, address(user1));
        // 0 fees
        assertEq(pho.balanceOf(address(owner)), phoBalanceOwnerBefore);
    }

    /// Purchase

    // Basic purchase - TODO: enable transfers
    function testPurchase() public {
        address recipient = user1;
        uint256 marketId = 0;
        uint256 amount = 10000;
        uint256 minAmountOut = 5000;

        MarketParams memory params = MarketParams({
            payoutToken: pho,
            quoteToken: ton,
            capacity: 10 ** 18,
            formattedInitialPrice: 10 ** 6,
            formattedMinimumPrice: 10 ** 4,
            vesting: 1000000000,
            conclusion: 10000000000,
            depositInterval: 24 hours,
            scaleAdjustment: 10
        });
        vm.prank(owner);
        bondFixedExpiryModule.createMarket(abi.encode(params));

        vm.prank(user1);
        bondFixedExpiryModule.purchase(recipient, marketId, amount, minAmountOut);
    }

    /// Specific to BondFixedExpiryDispatcher

    /// Basic example for deploy
    function testDeploy() public {
        uint48 expiry = uint48(block.timestamp + 100000);
        vm.prank(owner);
        bondFixedExpiryModule.deploy(ton, expiry);

        ERC20BondToken bond = bondFixedExpiryModule.bondTokens(ton, expiry);
        assertEq(address(bond.underlying()), address(ton));
        assertEq(bond.expiry(), expiry);
    }

    /// create()

    /// deploy()
}
