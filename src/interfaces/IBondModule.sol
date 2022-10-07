// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBondModule {
    /// Events
    event MarketCreated(
        uint256 indexed id,
        address indexed payoutToken,
        address indexed quoteToken,
        uint256 capacity,
        uint256 maxDiscount,
        uint256 initialPrice,
        uint256 termStart,
        uint256 termEnd
    );
    event MarketClosed(uint256 indexed id);
    event Tuned(uint256 indexed id, uint256 oldControlVariable, uint256 newControlVariable);
    event Bonded(uint256 indexed id, uint256 amount, uint256 payout);

    /// State vars

    /// @notice bond market info - bond controller sends payout tokens and recieves quote tokens
    struct BondMarket {
        ERC20 payoutToken; // payout token that bonders receive - PHO or TON
        ERC20 quoteToken; // quote token that bonders deposit
        uint256 capacity; // capacity (in payout token)
        uint256 initialPrice; // initial price
        uint256 maxDiscount; // max discount on initial price, max is 100% = 10**6
        uint256 termStart; // term start timestamp
        uint256 termEnd; // term end timestamp
        uint256 totalDebt; // total payout token debt from market
        uint256 sold; // payout tokens out
        uint256 purchased; // quote tokens in
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
        uint256 capacity; // capacity (in payout token)
        uint256 initialPrice; // initial price
        uint256 maxDiscount; // max discount on initial price
        uint256 termStart; // start
        uint256 termEnd; // end
    }

    /// @notice exchange quote tokens for a bond in a specified market
    /// @param recipient_ depositor address
    /// @param marketId bond market id
    /// @param amount_ amount to deposit in exchange for bond
    /// @return amount amount of payout token to be received from the bond
    /// @return timestamp when bond token can be redeemed for underlying
    function purchase(address recipient_, uint256 marketId, uint256 amount_)
        external
        returns (uint256, uint256);

    /// @notice current fee charged by the dispatcher based on the protocol fee
    /// @return fee in bps (3 decimal places)
    function getFee() external view returns (uint48);

    /// @notice set protocol fee
    /// @param fee_ protocol fee in basis points (3 decimal places)
    function setProtocolFee(uint48 fee_) external;

    /// @notice register a new market
    /// @param payoutToken_ token to be paid out by the market
    /// @param quoteToken_ token to be accepted by the market
    /// @param marketId id of the market being created
    function registerMarket(ERC20 payoutToken_, ERC20 quoteToken_)
        external
        returns (uint256 marketId);

    /// @notice claim fees accrued for input tokens and sends to protocol
    /// @param tokens_ array of tokens to claim fees for
    /// @param to_ address to send fees to
    function claimFees(ERC20[] memory tokens_, address to_) external;

    /// Controller

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
    /// @return payout amount of payout token to be received from the bond
    function purchaseBond(uint256 marketId, uint256 amount_) external returns (uint256 payout);

    /// View functions

    /// @notice provides information for the Dispatcher to execute purchases on a Market
    /// @param marketId market id
    /// @return payoutToken payout Token (token paid out) for the Market
    /// @return quoteToken quote Token (token received) for the Market
    /// @return termEnd term end
    /// @return maxDiscount max discount
    function getMarketInfoForPurchase(uint256 marketId)
        external
        view
        returns (ERC20 payoutToken, ERC20 quoteToken, uint256 termEnd, uint256 maxDiscount);
}
