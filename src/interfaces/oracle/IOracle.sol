// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

/// @title IOracle
/// @notice Interface for price oracles
/// @author Ekonomia: https://github.com/Ekonomia
interface IOracle {
    event PriceUpdateThresholdChanged(uint256 priceUpdateThreshold);
    event PriceUpdated(uint256 indexed twap, uint256 indexed blockTimestampLast, uint256 collatPrice);
    event PriceFeedUpdated(address indexed newPriceFeed, uint8 indexed newPriceFeedIndex); 

    /// @notice queries specified token price from priceOracle
    /// @param _token explicit token address that caller is querying price for
    /// @return price for token specified by caller
    function getPrice(address _token) external returns(uint256);

    /// @notice calculates price of inputToken
    /// @param _token token address that caller is querying price for
    /// @param _amountIn total value being priced
    /// @return amountOut price of inputToken based on current price
    function consult(address _token, uint _amountIn) external returns(uint256);

    /// @notice sets price threshold that triggers contingencies
    /// @param _priceUpdateThreshold The suggested price update threshold. Expressed in basis points, 10000 BP corresponding to 100%
    function setPriceUpdateThreshold(uint256 _priceUpdateThreshold) external;
}
