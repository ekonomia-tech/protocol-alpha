// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseSetup.t.sol";
import {Utilities} from "./utils/Utilities.sol";
import {TokenAuction} from "src/contracts/TokenAuction.sol";
import {PRBMathSD59x18} from "@prb-math/contracts/PRBMathSD59x18.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

///@notice Tests for TokenAuction
contract TokenAuctionTest is BaseSetup {
    using PRBMathSD59x18 for int256;
    using Strings for uint256;

    Utilities internal utils;
    TokenAuction internal usdcTokenAuction;
    TokenAuction internal daiTokenAuction;

    /// Addresses
    address payable[] internal users;

    /// Pricing params
    int256 public initialPrice = PRBMathSD59x18.fromInt(1).div(PRBMathSD59x18.fromInt(100));
    int256 public decayConstant = PRBMathSD59x18.fromInt(1);
    int256 public emissionRate = PRBMathSD59x18.fromInt(1).div(PRBMathSD59x18.fromInt(2));

    /// Encodings for revert tests
    bytes insufficientPayment = abi.encodeWithSignature("InsufficientPayment()");
    bytes insufficientTokens = abi.encodeWithSignature("InsufficientAvailableTokens()");

    /// Mock USDC, DAI TON setup
    uint256 internal testContractStartingUSDCBalance = 5e48;
    uint256 internal testContractStartingDAIBalance = 5e48;
    uint256 internal testContractStartingTONBalance = 5e48;
    uint256 public constant USDC_DELTA = 10 ** 12;
    /// decimal delta

    /// Events
    event AddedToWhiteList(address indexed addr);
    event RemovedFromWhiteList(address indexed addr);
    event MaxPerBuyerModified(uint256 maxPerBuyer);
    event PurchasedTokens(
        address indexed buyer,
        address indexed principalToken,
        address indexed payoutToken,
        uint256 numTokens,
        uint256 depositAmount
    );

    function _addPHOPool(address _pool) private {
        vm.startPrank(owner);
        pho.addPool(_pool);
        vm.stopPrank();
    }

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(5);

        /// TokenAuction contract
        vm.prank(owner);
        usdcTokenAuction = new TokenAuction(
            address(usdc),
            address(ton),
            initialPrice,
            decayConstant,
            emissionRate
        );

        vm.prank(owner);
        daiTokenAuction = new TokenAuction(
            address(dai),
            address(ton),
            initialPrice,
            decayConstant,
            emissionRate
        );

        /// Transfer TON to TokenAuction contracts
        vm.prank(address(usdcTokenAuction));
        ton.approve(address(usdcTokenAuction), testContractStartingTONBalance);

        vm.prank(address(daiTokenAuction));
        ton.approve(address(daiTokenAuction), testContractStartingDAIBalance);
        //ton.transfer(address(usdcTokenAuction), 10**36);

        uint256 usdcMintAmount = tenThousand_d6;
        uint256 daiMintAmount = tenThousand_d18;

        // Mint TON to USDC Token Auction contract
        _addPHOPool(address(usdcTokenAuction));
        vm.prank(address(usdcTokenAuction));
        ton.pool_mint(address(usdcTokenAuction), usdcMintAmount);

        // Mint TON to DAI Token Auction contract
        _addPHOPool(address(daiTokenAuction));
        vm.prank(address(daiTokenAuction));
        ton.pool_mint(address(daiTokenAuction), daiMintAmount);

        /// Approval for USDC TokenAuction
        usdc.approve(address(usdcTokenAuction), testContractStartingUSDCBalance);

        // Approval for DAI TokenAuction
        dai.approve(address(daiTokenAuction), testContractStartingDAIBalance);
    }

    /// Test only owner can add to whitelist
    function testRevertAddToWhitelistOnlyOwner() public {
        vm.prank(users[0]);
        vm.expectRevert("Ownable: caller is not the owner");
        usdcTokenAuction.addToWhiteList(users[1]);
    }

    /// Test only owner can remove from whitelist
    function testRevertRemoveFromWhitelistOnlyOwner() public {
        vm.prank(users[0]);
        vm.expectRevert("Ownable: caller is not the owner");
        usdcTokenAuction.removeFromWhiteList(users[1]);
    }

    /// Test only owner can modify maxPerBuyer
    function testRevertModifyMaxPerBuyerOnlyOwner() public {
        vm.prank(users[0]);
        vm.expectRevert("Ownable: caller is not the owner");
        usdcTokenAuction.modifyMaxPerBuyer(1000);
    }

    /// Test basic add to whitelist
    function testAddToWhitelist() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit AddedToWhiteList(users[0]);
        usdcTokenAuction.addToWhiteList(users[0]);
        assertTrue(usdcTokenAuction.whitelist(users[0]));
    }

    /// Test basic remove from whitelist
    function testRemoveFromWhitelist() public {
        vm.startPrank(owner);
        usdcTokenAuction.addToWhiteList(users[0]);
        assertTrue(usdcTokenAuction.whitelist(users[0]));
        vm.expectEmit(true, true, true, true);
        emit RemovedFromWhiteList(users[0]);
        usdcTokenAuction.removeFromWhiteList(users[0]);
        assertTrue(!usdcTokenAuction.whitelist(users[0]));
        vm.stopPrank();
    }

    /// Test basic modify maxPerBuyer
    function testModifyMaxPerBuyer() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit MaxPerBuyerModified(1000);
        usdcTokenAuction.modifyMaxPerBuyer(1000);
        assertEq(usdcTokenAuction.maxPerBuyer(), 1000);
    }

    /// Test for insufficient payment USDC
    function testInsuffientPaymentUSDC() public {
        vm.warp(block.timestamp + 10);
        uint256 purchaseAmount = 5;
        uint256 purchasePrice = usdcTokenAuction.purchasePrice(purchaseAmount);

        /// Whitelist user
        vm.prank(owner);
        usdcTokenAuction.addToWhiteList(users[0]);

        /// Send USDC to user and approve TokenAuction contract
        vm.prank(richGuy);
        usdc.transfer(users[0], oneThousand_d6);
        vm.prank(users[0]);
        usdc.approve(address(usdcTokenAuction), testContractStartingUSDCBalance);

        /// Attempt payment
        vm.prank(users[0]);
        vm.expectRevert(insufficientPayment);
        usdcTokenAuction.purchaseTokens(purchaseAmount, purchasePrice / USDC_DELTA - 1);
    }

    /// Test for insufficient payment DAI
    function testInsuffientPaymentDAI() public {
        vm.warp(block.timestamp + 10);
        uint256 purchaseAmount = 5;
        uint256 purchasePrice = daiTokenAuction.purchasePrice(purchaseAmount);

        /// Whitelist user
        vm.prank(owner);
        daiTokenAuction.addToWhiteList(users[1]);

        /// Send DAI to user and approve TokenAuction contract
        vm.prank(daiWhale);
        dai.transfer(users[1], one_d18);
        vm.prank(users[1]);
        dai.approve(address(daiTokenAuction), testContractStartingDAIBalance);

        /// Attempt payment
        vm.prank(users[1]);
        vm.expectRevert(insufficientPayment);
        daiTokenAuction.purchaseTokens(purchaseAmount, purchasePrice - 1);
    }

    /// Test for insufficient tokens
    function testInsufficientEmissions() public {
        /// 10 tokens available for sale
        vm.warp(block.timestamp + 10);

        /// Whitelist user
        vm.prank(owner);
        usdcTokenAuction.addToWhiteList(users[0]);

        /// Attempt to purchase 11
        vm.prank(users[0]);
        vm.expectRevert(insufficientTokens);
        usdcTokenAuction.purchaseTokens(11, 0);
    }

    /// Test for exceeds maxPerBuyer
    function testRevertMaxPerBuyer() public {
        vm.warp(block.timestamp + 10);
        uint256 purchaseAmount = 5;
        uint256 purchasePrice = usdcTokenAuction.purchasePrice(purchaseAmount);

        /// Whitelist user
        vm.prank(owner);
        usdcTokenAuction.addToWhiteList(users[0]);

        /// Set maxPerBuyer
        vm.prank(owner);
        usdcTokenAuction.modifyMaxPerBuyer(4);

        /// Attempt payment
        uint256 price = usdcTokenAuction.purchasePrice(5);
        assertTrue(purchasePrice > 0);
        vm.prank(users[0]);
        vm.expectRevert("MaxPerBuyer exceeded");
        usdcTokenAuction.purchaseTokens(5, price);
    }

    // Test for a proper purchase via USDC
    function testPurchaseCorrectlyUSDC() public {
        vm.warp(block.timestamp + 10);
        assertEq(ton.balanceOf(users[0]), 0);

        /// Whitelist user
        vm.prank(owner);
        usdcTokenAuction.addToWhiteList(users[0]);

        /// Get purchase price
        uint256 purchaseAmount = 5;
        uint256 purchasePrice = usdcTokenAuction.purchasePrice(purchaseAmount);
        assertTrue(purchasePrice > 0);

        /// Send USDC to user and approve TokenAuction contract
        vm.prank(richGuy);
        usdc.transfer(users[0], tenThousand_d6);
        vm.prank(users[0]);
        usdc.approve(address(usdcTokenAuction), testContractStartingUSDCBalance);

        /// Approval on contract -> send TON to user
        vm.prank(address(usdcTokenAuction));
        ton.approve(users[0], testContractStartingUSDCBalance);

        /// Purchase tokens
        vm.prank(users[0]);
        vm.expectEmit(true, true, true, true);
        emit PurchasedTokens(
            users[0], address(usdc), address(ton), purchaseAmount, purchasePrice / USDC_DELTA
            );
        usdcTokenAuction.purchaseTokens(purchaseAmount, purchasePrice / USDC_DELTA);

        /// Balance check on TON
        assertEq(ton.balanceOf(users[0]), purchaseAmount);

        /// Check purchasedAmounts
        assertEq(usdcTokenAuction.purchasedAmounts(users[0]), purchaseAmount);
    }

    // Test for a proper purchase via DAI
    function testPurchaseCorrectlyDAI() public {
        vm.warp(block.timestamp + 10);
        assertEq(ton.balanceOf(users[1]), 0);

        /// Whitelist user
        vm.prank(owner);
        daiTokenAuction.addToWhiteList(users[1]);

        /// Get purchase price
        uint256 purchaseAmount = 5;
        uint256 purchasePrice = daiTokenAuction.purchasePrice(purchaseAmount);
        assertTrue(purchasePrice > 0);

        /// Send USDC to user and approve TokenAuction contract
        vm.prank(daiWhale);
        dai.transfer(users[1], tenThousand_d18);
        vm.prank(users[1]);
        dai.approve(address(daiTokenAuction), testContractStartingDAIBalance);

        /// Approval on contract -> send TON to user
        vm.prank(address(daiTokenAuction));
        ton.approve(users[1], testContractStartingDAIBalance);

        /// Purchase tokens
        vm.prank(users[1]);
        vm.expectEmit(true, true, true, true);
        emit PurchasedTokens(users[1], address(dai), address(ton), purchaseAmount, purchasePrice);
        daiTokenAuction.purchaseTokens(purchaseAmount, purchasePrice);

        /// Balance check on TON
        assertEq(ton.balanceOf(users[1]), purchaseAmount);

        /// Check purchasedAmounts
        assertEq(daiTokenAuction.purchasedAmounts(users[1]), purchaseAmount);
    }

    fallback() external payable {}
}
