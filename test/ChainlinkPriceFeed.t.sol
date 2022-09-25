// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseSetup.t.sol";
import "src/contracts/Vault.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract ChainlinkPriceFeedTest is BaseSetup {
    event PriceFeedAdded(address indexed newToken, address indexed newFeed);
    event PriceFeedRemoved(address indexed removedToken, address indexed removedFeed);

    function testConstructor() public {
        assertEq(priceFeed.precisionDifference(), oracleResponsePrecision - oraclePrecision);
    }

    /// getPrice()

    function testGetPriceUSDC() public {
        AggregatorV3Interface USDCPriceFeed = AggregatorV3Interface(PriceFeed_USDCUSD);

        vm.prank(owner);
        priceFeed.addFeed(USDC_ADDRESS, PriceFeed_USDCUSD);

        uint256 internalPrice = priceFeed.getPrice(USDC_ADDRESS);
        (, int256 externalPrice,,,) = USDCPriceFeed.latestRoundData();

        assertEq(internalPrice, uint256(externalPrice) * (10 ** priceFeed.precisionDifference()));
    }

    function testGetPriceFRAX() public {
        AggregatorV3Interface FRAXPriceFeed = AggregatorV3Interface(PriceFeed_FRAXUSD);

        vm.prank(owner);
        priceFeed.addFeed(fraxAddress, PriceFeed_FRAXUSD);

        uint256 internalPrice = priceFeed.getPrice(fraxAddress);
        (, int256 externalPrice,,,) = FRAXPriceFeed.latestRoundData();

        assertEq(internalPrice, uint256(externalPrice) * (10 ** priceFeed.precisionDifference()));
    }

    function testGetPriceETH() public {
        AggregatorV3Interface ETHPriceFeed = AggregatorV3Interface(PriceFeed_ETHUSD);

        vm.prank(owner);
        priceFeed.addFeed(fraxAddress, PriceFeed_ETHUSD);

        uint256 internalPrice = priceFeed.getPrice(fraxAddress);
        (, int256 externalPrice,,,) = ETHPriceFeed.latestRoundData();

        assertEq(internalPrice, uint256(externalPrice) * (10 ** priceFeed.precisionDifference()));
    }

    function testCannotGetPriceFeedZeroAddress() public {
        vm.expectRevert("Price Feed: feed not registered");
        priceFeed.getPrice(address(0));
    }

    function testCannotGetPriceFeedNotRegistered() public {
        vm.expectRevert("Price Feed: feed not registered");
        priceFeed.getPrice(fraxBPLPToken);
    }

    /// addFeed()

    function testAddFeedUSDC() public {
        address USDCFeedAddress = priceFeed.priceFeeds(USDC_ADDRESS);
        assertTrue(USDCFeedAddress == address(0));

        vm.expectEmit(true, true, false, true);
        emit PriceFeedAdded(USDC_ADDRESS, PriceFeed_USDCUSD);
        _addUSDCFeed();

        assertEq(priceFeed.priceFeeds(USDC_ADDRESS), PriceFeed_USDCUSD);
    }

    function testCannotAddPriceFeedZeroAddress() public {
        vm.expectRevert("Price Feed: zero address detected");
        vm.prank(owner);
        priceFeed.addFeed(address(0), PriceFeed_USDCUSD);

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
        emit PriceFeedRemoved(USDC_ADDRESS, PriceFeed_USDCUSD);
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
        priceFeed.addFeed(USDC_ADDRESS, PriceFeed_USDCUSD);
    }
}