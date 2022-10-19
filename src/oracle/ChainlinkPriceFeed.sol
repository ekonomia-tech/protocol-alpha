// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "@oracle/IPriceOracle.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ChainlinkPriceFeed is IPriceOracle, Ownable {
    event FeedAdded(address indexed newToken, address indexed newFeed);
    event FeedRemoved(address indexed removedToken, address indexed removedFeed);

    /// the difference in precision between the decimal precision chainlink is returning to the wanted precision this contract returns
    uint256 public immutable precisionDifference;

    mapping(address => address) public priceFeeds;

    /// @param _precisionDifference the decimal precision difference between the chainlink oracle and the desired return value
    constructor(uint256 _precisionDifference) {
        require(_precisionDifference > 0, "Price Feed: precision must be >0");
        precisionDifference = _precisionDifference;
    }

    /// @param baseToken the base token to retrieve the price in USD with 18 decimals.
    function getPrice(address baseToken) external view returns (uint256) {
        require(priceFeeds[baseToken] != address(0), "Price Feed: feed not registered");
        (, int256 price,,,) = AggregatorV3Interface(priceFeeds[baseToken]).latestRoundData();
        require(price >= 0, "Price Feed: price < 0");
        return uint256(price) * (10 ** precisionDifference);
    }

    /// @notice add a price feed for a specific XXX/USD pair
    /// @param newToken the base token of the price feed
    /// @param newFeed the price feed contract address
    function addFeed(address newToken, address newFeed) external onlyOwner {
        require(
            newFeed != address(0) && newToken != address(0), "Price Feed: zero address detected"
        );
        require(priceFeeds[newToken] != newFeed, "Price Feed: feed registered");
        priceFeeds[newToken] = newFeed;
        emit FeedAdded(newToken, newFeed);
    }

    /// @notice remove price feed form the available price feeds
    /// @param feedToken the token of the feed to be removed
    function removeFeed(address feedToken) external onlyOwner {
        require(feedToken != address(0), "Price Feed: zero address detected");
        require(priceFeeds[feedToken] != address(0), "Price Feed: feed not registered");
        address deletedFeed = priceFeeds[feedToken];
        delete priceFeeds[feedToken];
        emit FeedRemoved(feedToken, deletedFeed);
    }
}
