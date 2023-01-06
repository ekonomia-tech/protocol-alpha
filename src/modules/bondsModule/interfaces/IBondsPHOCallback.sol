/// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

interface IBondsPHOCallback {
    error ZeroAddress();
    error SameAddress();
    error QuoteOracleNotAvailableForMarket();

    event QuoteOracleUpdated(uint256 marketId, address indexed oracleAddress);

    function updateQuoteOracle(uint256 marketId, address oracleAddress) external;
}
