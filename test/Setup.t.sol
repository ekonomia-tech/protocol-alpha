// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { EUSD } from "../src/contracts/EUSD.sol";
import {PIDController} from "../src/contracts/PIDController.sol";
import { Share } from "../src/contracts/Share.sol";
import {DummyOracle} from "../src/oracle/DummyOracle.sol";
import { Pool } from "../src/contracts/Pool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


abstract contract Setup is Test {
    
    EUSD public eusd;
    Share public share;
    PIDController public pid;
    DummyOracle public priceOracle;
    Pool public pool_usdc;
    // Pool public pool_usdc2;

    IERC20 usdc;
   
    address public owner = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045; // NOTE - vitalik.eth for tests but we may need a different address to supply USDC depending on our tests - vitalik only has 30k USDC
    address public timelock_address = address(100);
    address public controller = address(101);
    address public user1 = address(1);
    address public user2 = address(2);
    address public user3 = address(3);
    address public dummyAddress = address(4);
    address public richGuy = 0xed320Bf569E5F3c4e9313391708ddBFc58e296bb;

    uint256 public constant oneHundred = 100 * 10 ** 18;
    uint256 public constant twoHundred = 200 * 10 ** 18;
    uint256 public constant fiveHundred = 500 * 10 ** 18;
    uint256 public constant oneThousand = 1000 * 10 ** 18;
    uint256 public constant oneHundredThousandUSDC = 100000 * 10 ** 6;
    uint256 public constant oneHundredUSDC = 100 * 10 ** 6;
    uint256 public constant overPeg = (10 ** 6) + 6000;
    uint256 public constant underPeg = (10 ** 6)  - (6000);

    // uint256 poolMintAmount = 99750000;
    uint256 shareBurnAmount = 25 * 10 ** 16;
    uint256 minEUSDOut = 90 * 10 ** 18;

    uint256 public constant GENESIS_SUPPLY_EUSD = 10000 * 10 ** 18;
    uint256 public constant GENESIS_SUPPLY_USDC = 10000 * 10 ** 6;

    uint256 public constant PRICE_PRECISION = 10 ** 6;

    address public constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint256 public constant POOL_CEILING = (2 ** 256) - 1;

    constructor() {
        vm.startPrank(owner);
        eusd = new EUSD("Eusd", "EUSD", owner, timelock_address);
        share = new Share("Share", "SHARE", owner, timelock_address);
        share.setEUSDAddress(address(eusd));
        priceOracle = new DummyOracle();

        pid = new PIDController(address(eusd), owner, timelock_address, address(priceOracle));
        pid.setMintingFee(9500); // .95% at genesis
        pid.setRedemptionFee(4500); // .45% at genesis
        pid.setController(controller);
        eusd.setController(controller);

        usdc = IERC20(USDC_ADDRESS);
        pool_usdc = new Pool(address(eusd), address(share), address(pid), USDC_ADDRESS, owner, address(priceOracle), POOL_CEILING);
        eusd.addPool(address(pool_usdc));
        
        // new code to accomodate not using constructor to mint unbacked EUSD for tests
        usdc.approve(address(pool_usdc), GENESIS_SUPPLY_USDC);
        pool_usdc.mint1t1EUSD(GENESIS_SUPPLY_USDC, GENESIS_SUPPLY_EUSD);

        eusd.transfer(user1, oneThousand);
        eusd.transfer(user2, oneThousand);
        eusd.transfer(user3, oneThousand);

        // pool_usdc2 = new Pool(address(eusd), address(share), address(pid), USDC_ADDRESS, owner, address(priceOracle), POOL_CEILING);
        // eusd.addPool(address(pool_usdc2));

        usdc = IERC20(USDC_ADDRESS);
        // pool_usdc = new Pool(address(eusd), address(share), address(pid), USDC_ADDRESS, owner, address(priceOracle), POOL_CEILING);
        // pool_usdc2 = new Pool(address(eusd), address(share), address(pid), USDC_ADDRESS, owner, address(priceOracle), POOL_CEILING);

        // eusd.addPool(address(pool_usdc));
        // eusd.addPool(address(pool_usdc2));

        vm.stopPrank();
    }

}