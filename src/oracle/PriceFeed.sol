// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "../interfaces/IPriceOracle.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PriceFeed is IPriceOracle, Ownable {
    event PriceFeedAdded(address indexed newToken, address indexed newFeed);
    event PriceFeedRemoved(address indexed removedToken, address indexed removedFeed);

    address private constant USD = address(840);
    mapping(address => address) public priceFeeds;

    constructor() {}

    function getPrice(address baseToken) public view returns (uint256) {
        require(priceFeeds[baseToken] != address(0), "Price Feed: feed not registered");
        (, int256 price,,,) = AggregatorV3Interface(priceFeeds[baseToken]).latestRoundData();
        return uint256(price);
    }

    function addFeed(address newToken, address newFeed) external onlyOwner {
        require(
            newFeed != address(0) || newToken != address(0), "Price Feed: zero address detected"
        );
        require(priceFeeds[newToken] != newFeed, "Price Feed: feed registered");
        priceFeeds[newToken] = newFeed;
        emit PriceFeedAdded(newToken, newFeed);
    }

    function removeFeed(address removeToken) external onlyOwner {
        require(removeToken != address(0), "Price Feed: zero address detected");
        require(priceFeeds[removeToken] != address(0), "Price Feed: feed not registered");
        address deletedFeed = priceFeeds[removeToken];
        delete priceFeeds[removeToken];
        emit PriceFeedRemoved(removeToken, deletedFeed);
    }
}
