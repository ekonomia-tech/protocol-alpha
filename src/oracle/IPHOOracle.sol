// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

/// @title IOracle
/// @notice Interface for PHO oracle
/// @author Ekonomia: https://github.com/Ekonomia
interface IPHOOracle {
    event PriceUpdated(uint256 indexed latestPHOUSDPrice, uint256 indexed blockTimestampLast);
    // event PriceThresholdExceeded(bool priceThresholdChangeExceeded);
    event PriceUpdateThresholdChanged(uint256 priceUpdateThreshold);

    /// @notice gets latest PHO/USD price as per internal oracle
    /// @return price USD/PHO to 18 decimals
    function updatePrice() external returns (uint256);

    /// @notice sets the max amount the new price can differ from the last price, called the priceUpdateThreshold
    /// @param _priceUpdateThreshold the suggested price update threshold, expressed in basis points - 10 ** 6 BP corresponding to 100%
    function setPriceUpdateThreshold(uint256 _priceUpdateThreshold) external;
}
