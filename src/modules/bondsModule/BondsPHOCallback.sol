// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.13;

import {BondBaseCallback} from "@modules/bondsModule/interfaces/BondBaseCallback.sol";
import {IBondAggregator} from "@modules/bondsModule/interfaces/IBondAggregator.sol";
import {IBondsFTController} from "@modules/bondsModule/interfaces/IBondsFTController.sol";
import {IBondsPHOCallback} from "@modules/bondsModule/interfaces/IBondsPHOCallback.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {TransferHelper} from "@external/utils/TransferHelper.sol";
import "@oracle/IPriceOracle.sol";

/// @title Bond Callback
/// @notice Bond Callback Sample Contract
/// @dev Bond Protocol is a permissionless system to create Olympus-style bond markets
///      for any token pair. The markets do not require maintenance and will manage
///      bond prices based on activity. Bond issuers create BondMarkets that pay out
///      a Payout Token in exchange for deposited Quote Tokens. Users can purchase
///      future-dated Payout Tokens with Quote Tokens at the current market price and
///      receive Bond Tokens to represent their position while their bond vests.
///      Once the Bond Tokens vest, they can redeem it for the Quote Tokens.
///
/// @dev The Sample Callback is an implementation of the Base Callback contract that
///      checks if quote tokens have been passed in and transfers payout tokens from the
///      contract.
///
/// @author Oighty, Zeus, Potted Meat, indigo
contract BondsPHOCallback is BondBaseCallback, IBondsPHOCallback {
    using TransferHelper for ERC20;

    /// Market id to price oracle for calculation of value difference between quote amount and $PHO
    mapping(uint256 => IPriceOracle) public quoteOracles;

    /// Market Id to total unbacked minted
    mapping(uint256 => uint256) public marketUnbackedMinted;

    uint256 public totalUnbacked;

    IBondsFTController public bondsFTController;

    address public treasury;

    /* ========== CONSTRUCTOR ========== */

    constructor(IBondAggregator aggregator_, address bondsController_, address treasury_)
        BondBaseCallback(aggregator_)
    {
        bondsFTController = IBondsFTController(bondsController_);
        treasury = treasury_;
    }

    /* ========== CALLBACK ========== */

    /// @inheritdoc BondBaseCallback
    function _callback(
        uint256 id_,
        ERC20 quoteToken_,
        uint256 inputAmount_,
        ERC20 payoutToken_,
        uint256 outputAmount_
    ) internal override {
        IPriceOracle quoteOracle = quoteOracles[id_];
        if (address(quoteOracle) == address(0)) revert QuoteOracleNotAvailableForMarket();

        uint256 quoteTokenPrice = quoteOracle.getPrice(address(quoteToken_));
        uint256 quoteInUSD = quoteTokenPrice * inputAmount_ / (10 ** quoteToken_.decimals());

        if (outputAmount_ > quoteInUSD) {
            uint256 unbackedAmount = outputAmount_ - quoteInUSD;
            marketUnbackedMinted[id_] += unbackedAmount;
            totalUnbacked += unbackedAmount;
        }

        /// transfer the quote amount to the treasury
        quoteToken_.safeTransfer(treasury, inputAmount_);

        /// mint PHO back to the msg.sender
        bondsFTController.mintPHOForCallback(id_, outputAmount_);
    }

    function updateQuoteOracle(uint256 marketId, address oracleAddress) external onlyOwner {
        if (oracleAddress == address(0)) revert ZeroAddress();
        if (address(quoteOracles[marketId]) == oracleAddress) revert SameAddress();
        quoteOracles[marketId] = IPriceOracle(oracleAddress);
    }
}
