// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../BaseSetup.t.sol";
import "@oracle/wstETHOracle.sol";

contract wstETHOracleTest is BaseSetup {

    wstETHOracle public oracle;

    function setUp() public {
        vm.prank(owner);
        priceFeed.addFeed(STETH_ADDRESS, PRICEFEED_STETH);

        oracle = new wstETHOracle(address(priceFeed));
    }

    function testGetPrice() public {
        uint256 wstETHPrice = oracle.getPrice(WSTETH_ADDRESS);
        uint256 stETHPrice = priceFeed.getPrice(STETH_ADDRESS);
        uint stETHperToken = wsteth.tokensPerStEth();
        assertApproxEqAbs(wstETHPrice * stETHperToken / 10 ** 18, stETHPrice, 100000000000);
    }
}