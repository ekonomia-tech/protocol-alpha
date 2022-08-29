// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

/// @title IPHOPriceFeed
/// @notice Interface for price feeds that will be registered to the OracleAggregator
/// @author Ekonomia: https://github.com/Ekonomia
/// @dev all registered oracles will adhere to this
interface IPHOPriceFeed {
    event PriceUpdateThresholdChanged(uint256 priceUpdateThreshold);
    event PriceFeedInitialized(uint256[] indexed twap, uint256 indexed blockTimestampLast);
    event PriceUpdated(uint256[] indexed twap, uint256 indexed blockTimestampLast);

    function getPHOUSDPrice() external returns(uint256[2] memory);
    function consult(address token, uint amountIn) external returns(uint256);
    function setPriceUpdateThreshold(uint256 _priceUpdateThreshold) external;
}
