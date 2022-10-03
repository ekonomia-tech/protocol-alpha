// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "./BaseSetup.t.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/contracts/BondBaseDispatcher.sol";
import "src/contracts/BondFixedExpiryDispatcher.sol";
import "src/contracts/BondFixedExpiryController.sol";
import "src/contracts/BondBaseController.sol";
import "src/interfaces/IBondController.sol";

contract BondControllerTest is BaseSetup {
    // Contract relevant test constants
    address public protocol = 0xe688b84b23f322a994A53dbF8E15FA82CDB71127;
    BondFixedExpiryDispatcher public bondFixedExpiryDispatcher;
    BondFixedExpiryController public bondFixedExpiryController;

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
        bondFixedExpiryDispatcher = new BondFixedExpiryDispatcher(
            protocol,
            controller
        );

        vm.prank(owner);
        bondFixedExpiryController = new BondFixedExpiryController(
            address(bondFixedExpiryDispatcher),
            controller,
            address(pho),
            address(ton)
        );

        vm.prank(owner);
        bondFixedExpiryDispatcher.setBondController(address(bondFixedExpiryController));

        defaultTuneInterval = 24 hours;
        defaultTuneAdjustment = 1 hours;
        minDebtDecayInterval = 3 days;
        minDepositInterval = 1 hours;
        minMarketDuration = 1 days;
        minDebtBuffer = 10000; // 10%
    }

    /// Creating BondController

    // Cannot create BondController with zero address
    function testCannotCreateBondControllerZeroAddress() public {
        vm.expectRevert("BondController: zero address detected");
        vm.prank(owner);
        bondFixedExpiryController = new BondFixedExpiryController(
            address(0),
            controller,
            address(pho),
            address(ton)
        );

        vm.expectRevert("BondController: zero address detected");
        vm.prank(owner);
        bondFixedExpiryController = new BondFixedExpiryController(
            address(bondFixedExpiryDispatcher),
            address(0),
            address(pho),
            address(ton)
        );

        vm.expectRevert("BondController: zero address detected");
        vm.prank(owner);
        bondFixedExpiryController = new BondFixedExpiryController(
            address(bondFixedExpiryDispatcher),
            address(controller),
            address(0),
            address(ton)
        );

        vm.expectRevert("BondController: zero address detected");
        vm.prank(owner);
        bondFixedExpiryController = new BondFixedExpiryController(
            address(bondFixedExpiryDispatcher),
            address(controller),
            address(pho),
            address(0)
        );
    }

    /// createMarket()

    // Cannot create if not owner/controller
    function testCannotCreateMarketOnlyOwnerController() public {
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
        vm.expectRevert("BondController: not the owner or controller");
        vm.prank(user1);
        bondFixedExpiryController.createMarket(abi.encode(params));
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
        vm.expectRevert("BondController: payoutToken must be PHO or TON");
        vm.prank(owner);
        bondFixedExpiryController.createMarket(abi.encode(params));

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
        vm.expectRevert("BondController: createMarket invalid params");
        vm.prank(owner);
        bondFixedExpiryController.createMarket(abi.encode(params));

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
        vm.expectRevert("BondController: createMarket invalid params");
        vm.prank(owner);
        bondFixedExpiryController.createMarket(abi.encode(params));

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
        vm.expectRevert("BondController: createMarket invalid params");
        vm.prank(owner);
        bondFixedExpiryController.createMarket(abi.encode(params));

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
        vm.expectRevert("BondController: createMarket invalid params");
        vm.prank(owner);
        bondFixedExpiryController.createMarket(abi.encode(params));
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
        bondFixedExpiryController.createMarket(abi.encode(params));

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
        ) = bondFixedExpiryController.metadata(0);

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
        bondFixedExpiryController.createMarket(abi.encode(params));

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
        ) = bondFixedExpiryController.markets(0);

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
        bondFixedExpiryController.createMarket(abi.encode(params));

        // From prev
        uint256 targetDebt = (params.capacity * uint256(minDebtDecayInterval))
            / (uint256(params.conclusion - block.timestamp));

        uint256 currentScale = 10 ** uint8(36 + params.scaleAdjustment);

        uint256 currentMaxDebt = targetDebt + ((targetDebt * minDebtBuffer) / FEE_DECIMALS);
        uint256 currentControlVariable = (params.formattedInitialPrice * currentScale) / targetDebt;
        // Bond terms
        (uint256 controlVariable, uint256 maxDebt, uint48 vesting, uint48 conclusion) =
            bondFixedExpiryController.terms(0);
        assertEq(controlVariable, currentControlVariable);
        assertEq(maxDebt, currentMaxDebt);
        assertEq(vesting, params.vesting);
        assertEq(conclusion, params.conclusion);
    }

    /// Setting intervals

    // Cannot set intervals if not owner/controller
    function testCannotSetIntervalsOnlyOwnerController() public {
        uint32[] memory intervals = new uint32[](3);
        intervals[0] = 0;
        intervals[1] = 1;
        intervals[2] = 2;
        vm.expectRevert("BondController: not the owner or controller");
        vm.prank(user1);
        bondFixedExpiryController.setIntervals(0, intervals);
    }

    // Cannot set intervals to have any 0 or [0] < [1]
    function testCannotSetIntervalsInvalidParams() public {
        uint32[] memory intervals = new uint32[](3);
        intervals[0] = 0;
        intervals[1] = 1;
        intervals[2] = 2;

        // intervals[0] = 0
        vm.expectRevert("BondController: setIntervals invalid params");
        vm.prank(owner);
        bondFixedExpiryController.setIntervals(0, intervals);

        intervals[0] = 1;
        intervals[1] = 0;

        // intervals[1] = 0
        vm.expectRevert("BondController: setIntervals invalid params");
        vm.prank(owner);
        bondFixedExpiryController.setIntervals(0, intervals);

        intervals[1] = 2;
        intervals[2] = 0;

        // intervals[2] = 0
        vm.expectRevert("BondController: setIntervals invalid params");
        vm.prank(owner);
        bondFixedExpiryController.setIntervals(0, intervals);

        intervals[0] = 1;
        intervals[1] = 2;

        // intervals[0] < intervals[1]
        vm.expectRevert("BondController: setIntervals invalid params");
        vm.prank(owner);
        bondFixedExpiryController.setIntervals(0, intervals);
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
        bondFixedExpiryController.createMarket(abi.encode(params));

        uint32[] memory intervals = new uint32[](3);
        intervals[0] = 48 hours;
        intervals[1] = 2 hours;
        intervals[2] = 4 days;

        // intervals[0] = 0
        vm.prank(owner);
        bondFixedExpiryController.setIntervals(0, intervals);

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
        ) = bondFixedExpiryController.metadata(0);

        uint256 currentTuneIntervalCapacity =
            (10 ** 18 * uint256(intervals[0])) / uint256(10000000000 - block.timestamp);

        assertEq(tuneInterval, intervals[0]);
        assertEq(tuneIntervalCapacity, currentTuneIntervalCapacity);
        assertEq(tuneAdjustmentDelay, intervals[1]);
        assertEq(debtDecayInterval, intervals[2]);
    }

    /// Set defaults

    // Cannot setDefaults if not owner/controller
    function testCannotSetDefaultsOnlyOwnerController() public {
        uint32[] memory defaults = new uint32[](6);
        defaults[0] = 48 hours;
        defaults[1] = 2 hours;
        defaults[2] = 6 days;
        defaults[3] = 2 hours;
        defaults[4] = 2 days;
        defaults[5] = 20000;

        vm.expectRevert("BondController: not the owner or controller");
        vm.prank(user1);
        bondFixedExpiryController.setDefaults(defaults);
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
        bondFixedExpiryController.setDefaults(defaults);

        assertEq(bondFixedExpiryController.defaultTuneInterval(), defaults[0]);
        assertEq(bondFixedExpiryController.defaultTuneAdjustment(), defaults[1]);
        assertEq(bondFixedExpiryController.minDebtDecayInterval(), defaults[2]);
        assertEq(bondFixedExpiryController.minDepositInterval(), defaults[3]);
        assertEq(bondFixedExpiryController.minMarketDuration(), defaults[4]);
        assertEq(bondFixedExpiryController.minDebtBuffer(), defaults[5]);
    }

    /// Close market

    // Cannot closeMarket if not owner/controller
    function testCannotCloseMarketOnlyOwnerController() public {
        vm.expectRevert("BondController: not the owner or controller");
        vm.prank(user1);
        bondFixedExpiryController.closeMarket(0);
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
        bondFixedExpiryController.createMarket(abi.encode(params));

        vm.prank(owner);
        bondFixedExpiryController.closeMarket(0);

        (,,, uint48 conclusion) = bondFixedExpiryController.terms(0);
        (,, uint256 capacity,,,,,,) = bondFixedExpiryController.markets(0);

        assertEq(conclusion, uint48(block.timestamp));
        assertEq(capacity, 0);
    }

    // Purchase bond

    /// Cannot purchase bond unless bondDispatcher
    function testCannotPurchaseBondOnlyBondDispatcher() public {
        uint256 amount = 100000;
        uint256 minAmountOut = 50000;
        vm.expectRevert("BondController: not bond dispatcher");
        vm.prank(user1);
        bondFixedExpiryController.purchaseBond(0, amount, minAmountOut);
    }

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
        bondFixedExpiryController.createMarket(abi.encode(params));

        vm.warp(block.timestamp + 2 days + 1);

        vm.expectRevert("BondController: purchaseBond window passed");
        vm.prank(address(bondFixedExpiryDispatcher));
        bondFixedExpiryController.purchaseBond(0, amount, minAmountOut);
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
        bondFixedExpiryController.createMarket(abi.encode(params));

        uint256 targetDebt = (params.capacity * uint256(minDebtDecayInterval))
            / (uint256(params.conclusion - block.timestamp));

        vm.prank(address(bondFixedExpiryDispatcher));
        bondFixedExpiryController.purchaseBond(0, amount, minAmountOut);

        (,, uint256 capacity, uint256 totalDebt,,, uint256 sold, uint256 purchased,) =
            bondFixedExpiryController.markets(0);

        assertEq(capacity, 10 ** 18 - amount);
        assertEq(totalDebt, targetDebt + amount + 1);
        assertEq(purchased, amount);
        assertEq(sold, amount);
    }
}
