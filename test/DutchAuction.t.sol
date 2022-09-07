// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseSetup.t.sol";
import {DutchAuction} from "src/contracts/DutchAuction.sol";

///@notice Tests for DutchAuction
contract DutchAuctionTest is BaseSetup {
    DutchAuction internal usdcDutchAuction;
    DutchAuction internal daiDutchAuction;

    /// Mock USDC, DAI TON setup
    uint256 internal testContractStartingUSDCBalance = 5e48;
    uint256 internal testContractStartingDAIBalance = 5e48;
    uint256 internal testContractStartingTONBalance = 5e48;

    /// Events
    event AddedCommitment(
        address indexed buyer,
        address indexed auctionToken,
        address indexed paymentToken,
        uint256 commitment,
        uint256 decimals
    );
    event ModifiedAuctionParams(
        address indexed mod,
        address indexed auctionToken,
        address indexed paymentToken,
        uint256 newStartTime,
        uint256 newEndTime,
        uint256 newStartPrice,
        uint256 newMinPrice
    );

    // Params of auction
    uint256 public constant AUCTION_TOTAL_TOKENS = 5000;
    uint256 public constant AUCTION_START_TIME = 10;
    uint256 public constant AUCTION_END_TIME = 1010;
    uint256 public constant AUCTION_START_PRICE = 1 * 10 ** 18;
    uint256 public constant AUCTION_MIN_PRICE = 0.01 * 10 ** 18;
    uint256 public constant AUCTION_START_PRICE_USDC = 1 * 10 ** 30; // adjusted
    uint256 public constant AUCTION_MIN_PRICE_USDC = 0.01 * 10 ** 30; // adjusted

    function _addPHOPool(address _pool) private {
        vm.startPrank(owner);
        pho.addPool(_pool);
        vm.stopPrank();
    }

    function setUp() public {
        vm.prank(owner);
        daiDutchAuction = new DutchAuction();

        vm.prank(owner);
        usdcDutchAuction = new DutchAuction();

        /// Approve TON to DutchAuction contracts
        vm.prank(address(daiDutchAuction));
        ton.approve(address(daiDutchAuction), testContractStartingDAIBalance);

        /// Approve TON to USDC DutchAuction contracts
        vm.prank(address(usdcDutchAuction));
        ton.approve(address(usdcDutchAuction), testContractStartingTONBalance);

        uint256 daiMintAmount = tenThousand_d18;
        uint256 usdcMintAmount = tenThousand_d6;

        /// Mint TON to DAI Token Auction contract
        _addPHOPool(address(daiDutchAuction));
        vm.prank(address(daiDutchAuction));
        ton.pool_mint(address(daiDutchAuction), daiMintAmount);

        /// Mint TON to USDC Token Auction contract
        _addPHOPool(address(owner));
        vm.prank(address(owner));
        ton.pool_mint(address(owner), usdcMintAmount);

        /// Approval for DAI DutchAuction
        dai.approve(address(daiDutchAuction), testContractStartingDAIBalance);

        /// Approval for USDC DutchAuction
        usdc.approve(address(usdcDutchAuction), testContractStartingUSDCBalance);
    }

    /// Test initAuction() is only owner
    function testRevertInitAuctionOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        daiDutchAuction.initAuction(
            address(ton),
            address(usdc),
            AUCTION_TOTAL_TOKENS,
            AUCTION_START_TIME,
            AUCTION_END_TIME,
            AUCTION_START_PRICE,
            AUCTION_MIN_PRICE
        );
    }

    /// Test initAuction() start time must be > current timestamp
    function testRevertInitAuctionStartTimeTooEarly() public {
        vm.prank(owner);
        vm.expectRevert("DutchAuction: start time must be > current time");
        daiDutchAuction.initAuction(
            address(ton),
            address(usdc),
            AUCTION_TOTAL_TOKENS,
            AUCTION_START_TIME,
            AUCTION_END_TIME,
            AUCTION_START_PRICE,
            AUCTION_MIN_PRICE
        );
    }

    /// Test initAuction() end time must be > start time
    function testRevertInitAuctionEndTimeTooEarly() public {
        vm.warp(AUCTION_START_TIME - 1);
        vm.prank(owner);
        vm.expectRevert("DutchAuction: end time must be > start time");
        daiDutchAuction.initAuction(
            address(ton),
            address(usdc),
            AUCTION_TOTAL_TOKENS,
            AUCTION_START_TIME,
            AUCTION_START_TIME - 1,
            AUCTION_START_PRICE,
            AUCTION_MIN_PRICE
        );
    }

    /// Test initAuction() total tokens must be > 0
    function testRevertInitAuctionTotalTokensZero() public {
        vm.warp(AUCTION_START_TIME - 1);
        vm.prank(owner);
        vm.expectRevert("DutchAuction: total tokens must be > zero");
        daiDutchAuction.initAuction(
            address(ton),
            address(usdc),
            0,
            AUCTION_START_TIME,
            AUCTION_END_TIME,
            AUCTION_START_PRICE,
            AUCTION_MIN_PRICE
        );
    }

    /// Test initAuction() start price must be > min price
    function testRevertInitAuctionStartPriceMinPrice() public {
        vm.warp(AUCTION_START_TIME - 1);
        vm.prank(owner);
        vm.expectRevert("DutchAuction: start price must be > min price");
        daiDutchAuction.initAuction(
            address(ton),
            address(usdc),
            AUCTION_TOTAL_TOKENS,
            AUCTION_START_TIME,
            AUCTION_END_TIME,
            AUCTION_MIN_PRICE,
            AUCTION_MIN_PRICE
        );
    }

    /// Helper for setting up a basic auction for DAI
    function setupBasicAuction() public {
        vm.prank(owner);
        ton.approve(address(daiDutchAuction), AUCTION_TOTAL_TOKENS);
        vm.warp(AUCTION_START_TIME);
        vm.prank(owner);
        daiDutchAuction.initAuction(
            address(ton),
            address(dai),
            AUCTION_TOTAL_TOKENS,
            AUCTION_START_TIME,
            AUCTION_END_TIME,
            AUCTION_START_PRICE,
            AUCTION_MIN_PRICE
        );
    }

    /// Helper for setting up a basic auction for USDC
    function setupBasicAuctionUSDC() public {
        vm.prank(owner);
        ton.approve(address(usdcDutchAuction), AUCTION_TOTAL_TOKENS);
        vm.warp(AUCTION_START_TIME);
        vm.prank(owner);
        usdcDutchAuction.initAuction(
            address(ton),
            address(usdc),
            AUCTION_TOTAL_TOKENS,
            AUCTION_START_TIME,
            AUCTION_END_TIME,
            AUCTION_START_PRICE_USDC,
            AUCTION_MIN_PRICE_USDC
        );
    }

    /// Test initAuction() basics
    function testInitAuctionBasic() public {
        setupBasicAuction();
        (uint256 commitmentsTotal, bool finalized) = daiDutchAuction.marketStatus();
        assertEq(commitmentsTotal, 0);
        assertEq(daiDutchAuction.priceFunction(), AUCTION_START_PRICE);
        assertEq(daiDutchAuction.clearingPrice(), AUCTION_START_PRICE);
    }

    /// Test modifyAuctionParams() is onlyOwner
    function testRevertModifyAuctionParamsOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        daiDutchAuction.modifyAuctionParams(
            block.timestamp - 10, block.timestamp, AUCTION_START_PRICE / 2, AUCTION_MIN_PRICE / 2
        );
    }

    /// Test modifyAuctionParams() cannot have start time too early
    function testRevertModifyAuctionParamsStartTimeTooEarly() public {
        vm.prank(owner);
        vm.expectRevert("DutchAuction: start time is before current time");
        daiDutchAuction.modifyAuctionParams(
            block.timestamp - 10, block.timestamp, AUCTION_START_PRICE / 2, AUCTION_MIN_PRICE / 2
        );
    }

    /// Test modifyAuctionParams() cannot have end time too early
    function testRevertModifyAuctionParamsEndTimeTooEarly() public {
        vm.prank(owner);
        vm.expectRevert("DutchAuction: end time must be older than start time");
        daiDutchAuction.modifyAuctionParams(
            block.timestamp, block.timestamp, AUCTION_START_PRICE / 2, AUCTION_MIN_PRICE / 2
        );
    }

    /// Test modifyAuctionParams() cannot have start price > min price
    function testRevertModifyAuctionParamsStartHigherMinPrice() public {
        vm.prank(owner);
        vm.expectRevert("DutchAuction: start price must be > min price");
        daiDutchAuction.modifyAuctionParams(
            block.timestamp + 10, block.timestamp + 1000, AUCTION_START_PRICE / 2, AUCTION_START_PRICE
        );
    }

    /// Test modifyAuctionParams() cannot have min price be 0
    function testRevertModifyAuctionParamsMinPriceZero() public {
        vm.prank(owner);
        vm.expectRevert("DutchAuction: min price must be > 0");
        daiDutchAuction.modifyAuctionParams(
            block.timestamp + 10, block.timestamp + 1000, AUCTION_START_PRICE / 2, 0
        );
    }

    /// Test modifyAuctionParams() cannot happen if commits already
    function testRevertModifyAuctionParamsAlreadyCommits() public {
        setupBasicAuction();
        uint256 TOKENS_COMMITED = 10;
        commitTokens(user1, TOKENS_COMMITED);
        vm.prank(owner);
        vm.expectRevert("DutchAuction: auction cannot have already started");
        daiDutchAuction.modifyAuctionParams(
            block.timestamp + 10,
            block.timestamp + 1000,
            AUCTION_START_PRICE / 2,
            AUCTION_MIN_PRICE / 2
        );
    }

    /// Test modifyAuctionParams() sets times
    function testModifyAuctionParams() public {
        setupBasicAuction();
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit ModifiedAuctionParams(
            address(owner),
            address(ton),
            address(dai),
            block.timestamp + 10,
            block.timestamp + 1000,
            AUCTION_START_PRICE / 2,
            AUCTION_MIN_PRICE / 2
            );
        daiDutchAuction.modifyAuctionParams(
            block.timestamp + 10,
            block.timestamp + 1000,
            AUCTION_START_PRICE / 2,
            AUCTION_MIN_PRICE / 2
        );

        (uint256 startTime, uint256 endTime, uint256 totalTokens) = daiDutchAuction.marketInfo();

        (uint256 startPrice, uint256 minPrice) = daiDutchAuction.marketPrice();

        assertEq(startTime, block.timestamp + 10);
        assertEq(endTime, block.timestamp + 1000);

        assertEq(startPrice, AUCTION_START_PRICE / 2);
        assertEq(minPrice, AUCTION_MIN_PRICE / 2);
    }

    /// Test commitTokens basic
    function testCommitTokensBasic() public {
        setupBasicAuction();

        vm.prank(richGuy);
        dai.transfer(user1, tenThousand_d18);

        vm.prank(user1);
        dai.approve(address(daiDutchAuction), tenThousand_d18);

        vm.prank(user1);
        daiDutchAuction.commitTokens(10);

        (uint256 commitmentsTotal, bool finalized) = daiDutchAuction.marketStatus();
        assertEq(commitmentsTotal, 10);

        (uint256 startTime, uint256 endTime, uint256 totalTokens) = daiDutchAuction.marketInfo();

        assertEq(daiDutchAuction.tokenPrice(), (commitmentsTotal * 1e18) / AUCTION_TOTAL_TOKENS);

        uint256 maxCommitment = (totalTokens * (daiDutchAuction.clearingPrice())) / (1e18);

        /// 5000 * 8e18 / 1e18 = 40000 maxCommitment
        assertEq(daiDutchAuction.tokensClaimable(user1), AUCTION_TOTAL_TOKENS);
    }

    /// Helper function for basic commitTokens() - DAI
    function commitTokens(address currentUser, uint256 numTokens) public {
        setupBasicAuction();

        vm.prank(daiWhale);
        dai.transfer(currentUser, tenThousand_d18);

        vm.prank(currentUser);
        dai.approve(address(daiDutchAuction), tenThousand_d18);

        vm.prank(currentUser);
        daiDutchAuction.commitTokens(numTokens);
    }

    /// Helper function for basic commitTokens() - USDC
    function commitTokensUSDC(address currentUser, uint256 numTokens) public {
        setupBasicAuctionUSDC();

        vm.prank(richGuy);
        usdc.transfer(currentUser, tenThousand_d6);

        vm.prank(currentUser);
        usdc.approve(address(usdcDutchAuction), tenThousand_d6);

        vm.prank(currentUser);
        usdcDutchAuction.commitTokens(numTokens);
    }

    /// Test end and claim for unsuccessful auction before ending time
    function testRevertAuctionClaimUnsuccessfulPreEnd() public {
        setupBasicAuction();

        uint256 TOKENS_COMMITED = 10;
        commitTokens(user1, TOKENS_COMMITED);

        vm.warp(AUCTION_END_TIME - 1);
        vm.prank(user1);
        vm.expectRevert("DutchAuction: auction has not finished yet");
        daiDutchAuction.withdrawTokens();
    }

    /// Test end and claim for unsuccessful auction after ending time
    function testAuctionClaimUnsuccessfulBasic() public {
        setupBasicAuction();

        uint256 TOKENS_COMMITED = 10;
        commitTokens(user1, TOKENS_COMMITED);

        vm.warp(AUCTION_END_TIME + 10);
        assertTrue(daiDutchAuction.auctionEnded());

        uint256 originalPaymentTokenBalance = dai.balanceOf(address(user1));
        vm.prank(user1);
        daiDutchAuction.withdrawTokens();
        assertEq(ton.balanceOf(address(user1)), 0);
        assertEq(dai.balanceOf(address(user1)), originalPaymentTokenBalance + TOKENS_COMMITED);
        assertEq(daiDutchAuction.commitments(user1), 0);
    }

    /// Test that cancelAuction() is onlyOwner
    function testRevertCancelAuctionOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        daiDutchAuction.cancelAuction();
    }

    /// Test that cancelAuction() cannot happen if auction already finalized
    function testRevertCancelAuctionAlreadyFinalized() public {
        setupBasicAuction();
        vm.warp(AUCTION_END_TIME + 10);
        vm.prank(owner);
        daiDutchAuction.finalize();
        vm.prank(owner);
        vm.expectRevert("DutchAuction: auction already finalized");
        daiDutchAuction.cancelAuction();
    }

    /// Test that cancelAuction() cannot happen if auction already finalized
    function testRevertCancelAuctionAlreadyCommitted() public {
        setupBasicAuction();
        uint256 TOKENS_COMMITED = AUCTION_TOTAL_TOKENS;
        commitTokens(user1, AUCTION_TOTAL_TOKENS);
        vm.prank(owner);
        vm.expectRevert("DutchAuction: auction already committed");
        daiDutchAuction.cancelAuction();
    }

    /// Test that cancelAuction() transfers auction token
    function testCancelAuction() public {
        setupBasicAuction();
        uint256 ownerBalance = ton.balanceOf(address(owner));
        vm.prank(owner);
        daiDutchAuction.cancelAuction();
        assertEq(ton.balanceOf(address(owner)), ownerBalance + AUCTION_TOTAL_TOKENS);
    }

    /// Test that finalize() is onlyOwner
    function testRevertFinalizeOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        daiDutchAuction.finalize();
    }

    /// Test that auction must be initialized before finalizing
    function testRevertFinalizeBeforeInitialize() public {
        vm.prank(owner);
        vm.expectRevert("DutchAuction: auction not initialized");
        daiDutchAuction.finalize();
    }

    /// Test that auction must end before finalizing if not successful
    function testRevertFinalizeBeforeEnd() public {
        setupBasicAuction();
        vm.prank(owner);
        vm.expectRevert("DutchAuction: auction has not finished yet");
        daiDutchAuction.finalize();
    }

    /// Test that finalizing auction without success transfers auction token back to owner
    function testFinalizeUnsuccessfulAuction() public {
        setupBasicAuction();
        vm.warp(AUCTION_END_TIME + 10);
        uint256 ownerBalance = ton.balanceOf(address(owner));
        vm.prank(owner);
        daiDutchAuction.finalize();
        assertEq(ton.balanceOf(address(owner)), ownerBalance + AUCTION_TOTAL_TOKENS);
    }

    /// Test end and claim for successful auction
    function testAuctionClaimSuccessfulAuctionBasic() public {
        uint256 TOKENS_COMMITED = AUCTION_TOTAL_TOKENS;
        commitTokens(user1, AUCTION_TOTAL_TOKENS);
        vm.warp(AUCTION_END_TIME);
        assertTrue(daiDutchAuction.auctionEnded());
        uint256 originalPaymentTokenBalance = dai.balanceOf(address(user1));

        (uint256 commitmentsTotalInitial, bool finalizedInitial) = daiDutchAuction.marketStatus();
        uint256 daiBalanceOwner = dai.balanceOf(address(owner));

        vm.prank(owner);
        daiDutchAuction.finalize();

        assertEq(dai.balanceOf(address(owner)), daiBalanceOwner + AUCTION_TOTAL_TOKENS);

        (uint256 commitmentsTotal, bool finalized) = daiDutchAuction.marketStatus();

        vm.prank(user1);
        daiDutchAuction.withdrawTokens();
        assertEq(ton.balanceOf(address(user1)), AUCTION_TOTAL_TOKENS);
    }

    /// Test end and claim for successful auction with two users
    function testAuctionClaimSuccessfulAuctionTwoUsers() public {
        uint256 TOKENS_COMMITED = AUCTION_TOTAL_TOKENS;

        vm.expectEmit(true, true, true, true);
        emit AddedCommitment(
            address(user1), address(ton), address(dai), AUCTION_TOTAL_TOKENS / 4, 18
            );
        commitTokens(user1, AUCTION_TOTAL_TOKENS / 4);
        vm.expectEmit(true, true, true, true);
        emit AddedCommitment(
            address(user2), address(ton), address(dai), (3 * AUCTION_TOTAL_TOKENS) / 4, 18
            );
        commitTokens(user2, 3 * (AUCTION_TOTAL_TOKENS / 4));

        vm.warp(AUCTION_END_TIME);
        assertTrue(daiDutchAuction.auctionEnded());

        uint256 originalPaymentTokenBalance = dai.balanceOf(address(user1));
        uint256 daiBalanceOwner = dai.balanceOf(address(owner));

        vm.prank(owner);
        daiDutchAuction.finalize();

        assertEq(dai.balanceOf(address(owner)), daiBalanceOwner + AUCTION_TOTAL_TOKENS);

        vm.prank(user1);
        daiDutchAuction.withdrawTokens();

        vm.prank(user2);
        daiDutchAuction.withdrawTokens();

        assertEq(ton.balanceOf(address(user1)), AUCTION_TOTAL_TOKENS / 4);
        assertEq(ton.balanceOf(address(user2)), (3 * AUCTION_TOTAL_TOKENS) / 4);
    }

    /// USDC tests - 6 decimals

    /// Test end and claim for successful auction using USDC
    function testAuctionClaimSuccessfulAuctionUSDCBasic() public {
        uint256 TOKENS_COMMITED = AUCTION_TOTAL_TOKENS;
        vm.expectEmit(true, true, true, true);
        emit AddedCommitment(address(user1), address(ton), address(usdc), AUCTION_TOTAL_TOKENS, 6);
        commitTokensUSDC(user1, AUCTION_TOTAL_TOKENS);

        vm.warp(AUCTION_END_TIME);
        assertTrue(usdcDutchAuction.auctionEnded());

        uint256 originalPaymentTokenBalance = usdc.balanceOf(address(user1));

        uint256 usdcBalanceOwner = usdc.balanceOf(address(owner));
        vm.prank(owner);
        usdcDutchAuction.finalize();

        assertEq(usdc.balanceOf(address(owner)), usdcBalanceOwner + AUCTION_TOTAL_TOKENS);

        vm.prank(user1);
        usdcDutchAuction.withdrawTokens();

        assertEq(ton.balanceOf(address(user1)), AUCTION_TOTAL_TOKENS);
    }

    /// Test end and claim for successful auction with two users
    function testAuctionClaimSuccessfulAuctionTwoUsersUSDC() public {
        uint256 TOKENS_COMMITED = AUCTION_TOTAL_TOKENS;

        vm.expectEmit(true, true, true, true);
        emit AddedCommitment(
            address(user1), address(ton), address(usdc), AUCTION_TOTAL_TOKENS / 4, 6
            );
        commitTokensUSDC(user1, AUCTION_TOTAL_TOKENS / 4);
        vm.expectEmit(true, true, true, true);
        emit AddedCommitment(
            address(user2), address(ton), address(usdc), (3 * AUCTION_TOTAL_TOKENS) / 4, 6
            );
        commitTokensUSDC(user2, 3 * (AUCTION_TOTAL_TOKENS / 4));

        vm.warp(AUCTION_END_TIME);
        assertTrue(usdcDutchAuction.auctionEnded());

        uint256 originalPaymentTokenBalance = usdc.balanceOf(address(user1));
        uint256 usdcBalanceOwner = usdc.balanceOf(address(owner));

        vm.prank(owner);
        usdcDutchAuction.finalize();

        assertEq(usdc.balanceOf(address(owner)), usdcBalanceOwner + AUCTION_TOTAL_TOKENS);

        vm.prank(user1);
        usdcDutchAuction.withdrawTokens();

        vm.prank(user2);
        usdcDutchAuction.withdrawTokens();

        assertEq(ton.balanceOf(address(user1)), AUCTION_TOTAL_TOKENS / 4);
        assertEq(ton.balanceOf(address(user2)), (3 * AUCTION_TOTAL_TOKENS) / 4);
    }

    fallback() external payable {}
}
