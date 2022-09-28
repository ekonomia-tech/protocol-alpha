// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBondDispatcher} from "../interfaces/IBondDispatcher.sol";

interface IBondController {
    /// @notice Main information pertaining to bond market

    /// Events
    event MarketCreated(
        uint256 indexed id,
        address indexed payoutToken,
        address indexed quoteToken,
        uint48 vesting,
        uint256 initialPrice
    );
    event MarketClosed(uint256 indexed id);
    event Tuned(
        uint256 indexed id,
        uint256 oldControlVariable,
        uint256 newControlVariable
    );

    /// State vars

    /// @notice bond market info
    /// @dev bond controller sends payout tokens and recieves quote tokens
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

    /// @notice info used to control how a bond market changes
    struct BondTerms {
        uint256 controlVariable; // scaling variable for price
        uint256 maxDebt; // max payout token debt accrued
        uint48 vesting; // length of time from deposit to expiry if fixed-term, vesting timestamp if fixed-expiry
        uint48 conclusion; // timestamp when market no longer offered
    }

    /// @notice data needed for tuning bond market
    /// @dev timestamps in uint32 (not int32), so is not subject to Y2K38 overflow
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

    /// @notice control variable adjustment data
    struct Adjustment {
        uint256 change; // change
        uint48 lastAdjustment; // last adjustment
        uint48 timeToAdjusted; // how long until adjustment happens
        bool active;
    }

    /// @notice Market params
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

    /// @notice creates a new bond market - only allowed by controller
    /// @param params_ configuration data needed for market creation, encoded in a bytes array
    /// @dev see specific controller implementations for details on encoding the parameters.
    /// @return id id of new bond market
    function createMarket(bytes memory params_) external returns (uint256);

    /// @notice disable existing bond market
    /// @param marketId bond market id to close
    function closeMarket(uint256 marketId) external;

    /// @notice exchange quote tokens for a bond in a specified market, must be dispatcher
    /// @param marketId id of the Market the bond is being purchased from
    /// @param amount_ amount to deposit in exchange for bond (after fee has been deducted)
    /// @param minAmountOut_ min acceptable amount of bond to receive. Prevents frontrunning
    /// @return payout amount of payout token to be received from the bond
    function purchaseBond(
        uint256 marketId,
        uint256 amount_,
        uint256 minAmountOut_
    ) external returns (uint256 payout);

    /// @notice set market intervals to different values than the defaults
    /// @dev tuneInterval should be greater than tuneAdjustmentDelay
    /// @param marketId market id
    /// @param intervals_ array of intervals (3)
    /// 1. Tune interval - Frequency of tuning
    /// 2. Tune adjustment delay - Time to implement downward tuning adjustments
    /// 3. Debt decay interval - Interval over which debt should decay completely
    function setIntervals(uint256 marketId, uint32[] calldata intervals_)
        external;

    /// @notice set the controller defaults
    /// @notice must be policy
    /// @param defaults_ array of default values
    /// 1. Tune interval - amount of time between tuning adjustments
    /// 2. Tune adjustment delay - amount of time to apply downward tuning adjustments
    /// 3. Minimum debt decay interval - minimum amount of time to let debt decay to zero
    /// 4. Minimum deposit interval - minimum amount of time to wait between deposits
    /// 5. Minimum market duration - minimum amount of time a market can be created for
    /// 6. Minimum debt buffer - the minimum amount of debt over the initial debt to trigger a market shutdown
    /// @dev The defaults set here are important to avoid edge cases in market behavior, e.g. a very short market reacts doesn't tune well
    /// @dev Only applies to new markets that are created after the change
    function setDefaults(uint32[] memory defaults_) external;

    /// View functions

    /// @notice provides information for the Dispatcher to execute purchases on a Market
    /// @param marketId market id
    /// @return payoutToken payout Token (token paid out) for the Market
    /// @return quoteToken quote Token (token received) for the Market
    /// @return vesting timestamp or duration for vesting, implementation-dependent
    /// @return maxPayout maximum amount of payout tokens you can purchase in one transaction
    function getMarketInfoForPurchase(uint256 marketId)
        external
        view
        returns (
            ERC20 payoutToken,
            ERC20 quoteToken,
            uint48 vesting,
            uint256 maxPayout
        );

    /// @notice Payout due for amount of quote tokens
    /// @dev Accounts for debt and control variable decay so it is up to date
    /// @param amount_ amount of quote tokens to spend
    /// @param marketId bond market id
    /// Inputting the zero address will take into account just the protocol fee.
    /// @return amount of payout tokens to be paid
    function payoutFor(uint256 amount_, uint256 marketId)
        external
        view
        returns (uint256);

    /// @notice returns maximum amount of quote token accepted by the market
    /// @param marketId bond market id
    function maxAmountAccepted(uint256 marketId)
        external
        view
        returns (uint256);

    /// View functions

    /// @notice calculate market price of payout token in quote tokens
    /// @dev p = CV * D where CV is control variable and D is debt
    /// @param marketId bond market id
    /// @return price for market in configured decimals
    function marketPrice(uint256 marketId) external view returns (uint256);

    /// @notice calculate debt factoring in decay
    /// @dev accounts for debt decay since last deposit
    /// @param marketId bond market id
    /// @return current debt for market in payout token decimals
    function currentDebt(uint256 marketId) external view returns (uint256);

    /// @notice up to date control variable
    /// @dev accounts for control variable adjustment
    /// @param marketId bond market id
    /// @return cv control variable for market in payout token decimals
    function currentControlVariable(uint256 marketId)
        external
        view
        returns (uint256);
}
