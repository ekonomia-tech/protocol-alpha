// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

/// @title IOracle
/// @notice Interface for PHO oracle
/// @author Ekonomia: https://github.com/Ekonomia
interface IOracle {
    event PriceUpdated(uint256 indexed latestPHOUSDPrice, uint256 indexed blockTimestampLast);
    event PriceSourceUpdated(address indexed priceSource); 
    event PriceUpdateThresholdChanged(uint256 priceUpdateThreshold);

    /// @notice gets latest PHO/USD price as per internal oracle
    /// @return price USD/PHO to 18 decimals
    /// TODO - see note in PHOTWAPOracle for this function regarding return value type
    function getPrice() external returns(int);

    /// @notice calculates return amount of inputToken with last recorded PHO price
    /// @dev varies in the units that the return value is in based on type of oracle (ex. TWAP vs PriceFeed)
    /// @param token input ERC20 address
    /// @param amountIn total value of input token being priced
    /// @return amountOut amount of inputToken (scaled by d18 in other pair token, based on current price
    function consult(address _token, uint256 _amountIn) external returns(uint256);

    /// @notice set the price source address that this oracle interacts with
    /// @param _priceSource address for price source
    function setPriceSource(address _priceSource) external;

    /// @notice sets the suggested price update threshold
    /// @param _priceUpdateThreshold the suggested price update threshold, expressed in basis points - 10 ** 6 BP corresponding to 100%
    function setPriceUpdateThreshold(uint256 _priceUpdateThreshold) external;
}
