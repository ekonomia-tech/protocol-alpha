// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { EUSD } from "../src/contracts/EUSD.sol";
import {PIDController} from "../src/contracts/PIDController.sol";
// import {ChainlinkETHUSDPriceConsumer} from "../src/contracts/oracle/ChainlinkETHUSDPriceConsumer.sol";
// import {DummyUniswapPairOracle} from "../src/contracts/oracle/DummyUniswapPairOracle.sol";
import { Share } from "../src/contracts/Share.sol";
import {PriceOracle} from "../src/oracle/PriceOracle.sol";
import { Pool } from "../src/contracts/Pool.sol";

// import { AddressesRegistry } from "../../contracts/AddressesRegistry.sol";

contract Setup is Test {
    
    EUSD public eusd;
    Share public share;
    PIDController public pid;
    PriceOracle public priceOracle;
    // DummyUniswapPairOracle public dummyOracle;
    // ChainlinkETHUSDPriceConsumer public eth_usd_pricer;
   
    address public owner = address(0x1337);
    address public timelock_address = address(100);
    address public controller = address(101);
    address public user1 = address(1);
    address public user2 = address(2);
    address public user3 = address(3);
    address public dummyAddress = address(4);

    uint256 public fiveHundred = 500 * 10 ** 8;
    uint256 public oneHundred = 100 * 10 ** 8;
    uint256 public fifty = 50 * 10 ** 8;
    uint256 public twentyFive = 25 * 10 ** 8;
    uint256 public twoHundred = 200 * 10 ** 8;
    uint256 public oneThousand = 1000 * 10 ** 8;

    uint256 public constant GENESIS_SUPPLY = 2000000 * 10 ** 18;

    address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function setUp() public {
        vm.startPrank(owner);
        eusd = new EUSD("Eusd", "EUSD", owner, timelock_address, GENESIS_SUPPLY);
        share = new Share("Share", "SHARE", owner, timelock_address);
        share.setEUSDAddress(address(eusd));
        priceOracle = new PriceOracle();

        pid = new PIDController(address(eusd), owner, timelock_address, address(priceOracle));

        eusd.transfer(user1, oneThousand);
        eusd.transfer(user2, oneThousand);
        eusd.transfer(user3, oneThousand);
        eusd.addPool(owner);
        eusd.setController(controller);

        vm.stopPrank();
    }


}