// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { EUSD } from "../src/contracts/EUSD.sol";
import {PIDController} from "../src/contracts/PIDController.sol";
import { Share } from "../src/contracts/Share.sol";
import {PriceOracle} from "../src/oracle/PriceOracle.sol";
import { Pool } from "../src/contracts/Pool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract Setup is Test {
    
    EUSD public eusd;
    Share public share;
    PIDController public pid;
    PriceOracle public priceOracle;
    // DummyUniswapPairOracle public dummyOracle;
    Pool public pool_usdc;
    IERC20 usdc;
   
    address public owner = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045; // vitalik.eth for tests
    address public timelock_address = address(100);
    address public controller = address(101);
    address public user1 = address(1);
    address public user2 = address(2);
    address public user3 = address(3);
    address public dummyAddress = address(4);
    address public richGuy = 0xed320Bf569E5F3c4e9313391708ddBFc58e296bb;


    uint256 public fiveHundred = 500 * 10 ** 8;
    uint256 public oneHundred = 100 * 10 ** 8;
    uint256 public fifty = 50 * 10 ** 8;
    uint256 public twentyFive = 25 * 10 ** 8;
    uint256 public twoHundred = 200 * 10 ** 8;
    uint256 public oneThousand = 1000 * 10 ** 8;

    uint256 public constant GENESIS_SUPPLY = 2000000 * 10 ** 18;
    uint256 public constant PRICE_PRECISION = 1e6;

    address public constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint256 public constant POOL_CEILING = (2 ** 256) - 1; 

    function setUp() public {
        vm.startPrank(owner);
        eusd = new EUSD("Eusd", "EUSD", owner, timelock_address, GENESIS_SUPPLY);
        share = new Share("Share", "SHARE", owner, timelock_address);
        share.setEUSDAddress(address(eusd));
        priceOracle = new PriceOracle();

        pid = new PIDController(address(eusd), owner, timelock_address, address(priceOracle));
        pid.setMintingFee(9500); // .95% at genesis
        pid.setRedemptionFee(4500); // .45% at genesis
        pid.setController(controller);
        
        eusd.transfer(user1, oneThousand);
        eusd.transfer(user2, oneThousand);
        eusd.transfer(user3, oneThousand);
        eusd.addPool(owner);
        eusd.setController(controller);

        usdc = IERC20(USDC_ADDRESS);
        pool_usdc = new Pool(address(eusd), address(share), address(pid), USDC_ADDRESS, owner, address(priceOracle), POOL_CEILING);
        eusd.addPool(address(pool_usdc));

        console.log("owner: %s", owner);
        console.log("eusd: %s", address(eusd));
        console.log("share: %s", address(share));
        console.log("timelock_address: %s", timelock_address);
        console.log("priceOracle: %s", address(priceOracle));
        console.log("pid: %s", address(pid));
        console.log("usdc: %s", address(usdc));
        console.log("pool_usdc: %s", address(pool_usdc));


        vm.stopPrank();
    }


}