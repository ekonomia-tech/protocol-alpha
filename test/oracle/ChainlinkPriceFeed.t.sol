// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../BaseSetup.t.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract ChainlinkPriceFeedTest is BaseSetup {
    event FeedAdded(address indexed newToken, address indexed newFeed);
    event FeedRemoved(address indexed removedToken, address indexed removedFeed);

    function testConstructor() public {
        assertEq(priceFeed.precisionDifference(), PRECISION_DIFFERENCE);
    }

    /// getPrice()

    function testGetPriceUSDC() public {
        AggregatorV3Interface USDCPriceFeed = AggregatorV3Interface(PRICEFEED_USDCUSD);

        vm.prank(owner);
        priceFeed.addFeed(USDC_ADDRESS, PRICEFEED_USDCUSD);

        uint256 internalPrice = priceFeed.getPrice(USDC_ADDRESS);
        (, int256 externalPrice,,,) = USDCPriceFeed.latestRoundData();

        assertEq(internalPrice, uint256(externalPrice) * (10 ** priceFeed.precisionDifference()));
    }

    function testGetPriceFRAX() public {
        AggregatorV3Interface FRAXPriceFeed = AggregatorV3Interface(PRICEFEED_FRAXUSD);

        vm.prank(owner);
        priceFeed.addFeed(FRAX_ADDRESS, PRICEFEED_FRAXUSD);

        uint256 internalPrice = priceFeed.getPrice(FRAX_ADDRESS);
        (, int256 externalPrice,,,) = FRAXPriceFeed.latestRoundData();

        assertEq(internalPrice, uint256(externalPrice) * (10 ** priceFeed.precisionDifference()));
    }

    function testGetPriceETH() public {
        AggregatorV3Interface ETHPriceFeed = AggregatorV3Interface(PRICEFEED_ETHUSD);

        vm.prank(owner);
        priceFeed.addFeed(ETH_NULL_ADDRESS, PRICEFEED_ETHUSD);

        uint256 internalPrice = priceFeed.getPrice(ETH_NULL_ADDRESS);
        (, int256 externalPrice,,,) = ETHPriceFeed.latestRoundData();

        assertEq(internalPrice, uint256(externalPrice) * (10 ** priceFeed.precisionDifference()));
    }

    function testCannotGetPriceFeedZeroAddress() public {
        vm.expectRevert("Price Feed: feed not registered");
        priceFeed.getPrice(address(0));
    }

    function testCannotGetPriceFeedNotRegistered() public {
        vm.expectRevert("Price Feed: feed not registered");
        priceFeed.getPrice(FRAXBP_LP_TOKEN);
    }

    /// addFeed()

    function testAddFeedUSDC() public {
        address USDCFeedAddress = priceFeed.priceFeeds(USDC_ADDRESS);
        assertTrue(USDCFeedAddress == address(0));

        vm.expectEmit(true, true, false, true);
        emit FeedAdded(USDC_ADDRESS, PRICEFEED_USDCUSD);
        _addUSDCFeed();

        assertEq(priceFeed.priceFeeds(USDC_ADDRESS), PRICEFEED_USDCUSD);
    }

    function testCannotAddPriceFeedZeroAddress() public {
        vm.expectRevert("Price Feed: zero address detected");
        vm.prank(owner);
        priceFeed.addFeed(address(0), PRICEFEED_USDCUSD);

        vm.expectRevert("Price Feed: zero address detected");
        vm.prank(owner);
        priceFeed.addFeed(USDC_ADDRESS, address(0));
    }

    function testCannotAddFeedAlreadyRegistered() public {
        _addUSDCFeed();
        vm.expectRevert("Price Feed: feed registered");
        _addUSDCFeed();
    }

    /// removeFeed()

    function testRemoveFeedUSDC() public {
        _addUSDCFeed();

        vm.expectEmit(true, true, false, true);
        emit FeedRemoved(USDC_ADDRESS, PRICEFEED_USDCUSD);
        vm.prank(owner);
        priceFeed.removeFeed(USDC_ADDRESS);

        assertEq(priceFeed.priceFeeds(USDC_ADDRESS), address(0));
    }

    function testCannotRemoveFeedZeroAddress() public {
        vm.expectRevert("Price Feed: zero address detected");
        vm.prank(owner);
        priceFeed.removeFeed(address(0));
    }

    function testCannotRemoveFeedNotRegistered() public {
        vm.expectRevert("Price Feed: feed not registered");
        vm.prank(owner);
        priceFeed.removeFeed(USDC_ADDRESS);
    }
    /// private functions

    function _addUSDCFeed() private {
        vm.prank(owner);
        priceFeed.addFeed(USDC_ADDRESS, PRICEFEED_USDCUSD);
    }
}
