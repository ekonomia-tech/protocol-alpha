// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "../interfaces/IPriceOracle.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ChainlinkPriceFeed is IPriceOracle, Ownable {
    event PriceFeedAdded(address indexed newToken, address indexed newFeed);
    event PriceFeedRemoved(address indexed removedToken, address indexed removedFeed);

    uint256 public immutable precisionDifference;

    mapping(address => address) public priceFeeds;

    constructor(uint256 _oraclePrecision, uint256 _responsePrecision) {
        require(
            _responsePrecision >= _oraclePrecision && _oraclePrecision != 0
                && _responsePrecision != 0,
            "Price Feed: bad values"
        );
        precisionDifference = _responsePrecision - _oraclePrecision;
    }

    function getPrice(address baseToken) external view returns (uint256) {
        require(priceFeeds[baseToken] != address(0), "Price Feed: feed not registered");
        (, int256 price,,,) = AggregatorV3Interface(priceFeeds[baseToken]).latestRoundData();
        require(price >= 0, "Price Feed: price < 0");
        return uint256(price) * (10 ** precisionDifference);
    }

    function addFeed(address newToken, address newFeed) external onlyOwner {
        require(
            newFeed != address(0) && newToken != address(0), "Price Feed: zero address detected"
        );
        require(priceFeeds[newToken] != newFeed, "Price Feed: feed registered");
        priceFeeds[newToken] = newFeed;
        emit PriceFeedAdded(newToken, newFeed);
    }

    function removeFeed(address feedToken) external onlyOwner {
        require(feedToken != address(0), "Price Feed: zero address detected");
        require(priceFeeds[feedToken] != address(0), "Price Feed: feed not registered");
        address deletedFeed = priceFeeds[feedToken];
        delete priceFeeds[feedToken];
        emit PriceFeedRemoved(feedToken, deletedFeed);
    }
}
