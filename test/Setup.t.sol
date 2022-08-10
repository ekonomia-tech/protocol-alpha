// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { EUSD } from "../src/contracts/EUSD.sol";
import {PIDController} from "../src/contracts/PIDController.sol";
import {ChainlinkETHUSDPriceConsumer} from "../src/contracts/oracle/ChainlinkETHUSDPriceConsumer.sol";
import {DummyUniswapPairOracle} from "../src/contracts/oracle/DummyUniswapPairOracle.sol";
import { Share } from "../src/contracts/Share.sol";


// import { AddressesRegistry } from "../../contracts/AddressesRegistry.sol";

contract Setup is Test {
    
    EUSD public eusd;
    Share public share;
    PIDController public pid;
    DummyUniswapPairOracle public dummyOracle;
    ChainlinkETHUSDPriceConsumer public eth_usd_pricer;
   
    address public owner = address(0x1337);
    address public timelock_address = address(42);
    address public controller = address(56);
    address public user1 = address(1);
    address public user2 = address(2);
    address public user3 = address(3);
    address public dummyAddress = address(23);

    uint256 public fiveHundred = 500 * 10**8;
    uint256 public oneHundred = 100 * 10**8;
    uint256 public fifty = 50 * 10**8;
    uint256 public twentyFive = 25 * 10**8;
    uint256 public twoHundred = 200 * 10**8;
    uint256 public oneThousand = 1000 * 10**8;

    uint256 public constant GENESIS_SUPPLY = 2000000e18;

    address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    uint eusdDummyPrice = 1; // TODO - dummy prices for early tests
    uint shareDummyPrice = 1; // TODO - dummy prices for early tests

    function setUp() public {
        vm.startPrank(owner);
        eusd = new EUSD("Eusd", "EUSD", owner, timelock_address);
        share = new Share("Share", "SHARE", owner, timelock_address);
        share.setEUSDAddress(address(eusd));

        pid = new PIDController(eusd, owner, timelock_address);
        // eth_usd_pricer = new ChainlinkETHUSDPriceConsumer(address(eusd), weth, owner, timelock_address);
        eth_usd_pricer = new ChainlinkETHUSDPriceConsumer();

        dummyOracle = new DummyUniswapPairOracle(weth, address(eusd), address(share), owner, timelock_address);

        pid.setETHUSDOracle(address(eth_usd_pricer));
        pid.setEUSDEthOracle(address(dummyOracle), weth);
        pid.setSHAREEthOracle(address(dummyOracle), weth);

        dummyOracle.setDummyPrice(address(eusd), eusdDummyPrice);
        dummyOracle.setDummyPrice(address(share), shareDummyPrice);

        // TODO - make an addressesRegistry
        // addressesRegistry = new AddressesRegistry();
        // addressesRegistry.setAddress("EUSD", address(eusd)); 
        // eusd.registerTeller(address());

        eusd.transfer(user1, oneThousand);
        eusd.transfer(user2, oneThousand);
        eusd.transfer(user3, oneThousand);
        eusd.addPool(owner);
        eusd.setController(controller);

        vm.stopPrank();
    }


}