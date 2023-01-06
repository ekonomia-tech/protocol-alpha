// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../BaseSetup.t.sol";
import {BondsController} from "@modules/bondsModule/BondsController.sol";
import {BondsPHOCallback} from "@modules/bondsModule/BondsPHOCallback.sol";
import {IBondAuctioneer} from "@modules/bondsModule/interfaces/IBondAuctioneer.sol";
import {IBondAggregator} from "@modules/bondsModule/interfaces/IBondAggregator.sol";
import {IBondTeller} from "@modules/bondsModule/interfaces/IBondTeller.sol";
import {IBondFixedTermTeller} from "@modules/bondsModule/interfaces/IBondFixedTermTeller.sol";
import {ERC1155} from "@external/Tokens/ERC1155.sol";
import {ERC20 as ERC20Solmate} from "@solmate/tokens/ERC20.sol";

contract BondsControllerTest is BaseSetup {
    error ZeroAddress();
    error ZeroValue();
    error NotTONTimelock();
    error MarketIsNotLive();
    error MarketNotRegistered();
    error NoBalanceAvailable();

    struct MarketParams {
        address payoutToken;
        address quoteToken;
        address callbackAddr;
        bool capacityInQuote;
        uint256 capacity;
        uint256 formattedInitialPrice;
        uint256 formattedMinimumPrice;
        uint32 debtBuffer;
        uint48 vesting;
        uint48 conclusion;
        uint32 depositInterval;
        int8 scaleAdjustment;
    }

    BondsController public bondsController;
    BondsPHOCallback public phoCallback;
    IBondAuctioneer public auctioneer;
    IBondTeller public teller;

    /// We set the prices as the prices of opening the bond. please review the bond protocol market creation for more info.
    uint256 public constant TON_PRICE = 10 * ONE_D18;
    uint256 public constant WETH_PRICE = 1250 * ONE_D18;
    uint256 public constant TON_SCALED_ADJUSTMENT = 1;
    uint256 public constant PHO_SCALED_ADJUSTMENT = 0;
    uint256 public constant SCALED_DECIMALS = 36;
    uint256 public constant VESTING_PERIOD = 7 days;
    address public constant AUCTIONEER_OWNER = 0x007BD11FCa0dAaeaDD455b51826F9a015f2f0969;

    function setUp() public {
        auctioneer = IBondAuctioneer(BOND_PROTOCOL_FIXED_TERM_AUCTIONEER);
        teller = auctioneer.getTeller();

        bondsController = new BondsController(
            address(moduleManager),
            address(TONTimelock), 
            address(treasury), 
            BOND_PROTOCOL_AGGREGATOR_ADDRESS
        );

        vm.prank(address(PHOTimelock));
        moduleManager.addModule(address(bondsController));

        vm.startPrank(address(TONTimelock));

        moduleManager.setPHOCeilingForModule(address(bondsController), 2000000 * 10 ** 18); // 2m ceiling
        vm.warp(block.timestamp + moduleManager.moduleDelay());
        moduleManager.executeCeilingUpdate(address(bondsController));

        phoCallback = new BondsPHOCallback(
            IBondAggregator(BOND_PROTOCOL_AGGREGATOR_ADDRESS), 
            address(bondsController), 
            address(treasury)
        );

        vm.stopPrank();

        vm.prank(AUCTIONEER_OWNER);
        auctioneer.setCallbackAuthStatus(owner, true);

        _fundAndApproveWETH(user1, address(bondsController), 10 ether, 10 ether);

        vm.prank(owner);
        ton.approve(address(teller), 10 * ONE_MILLION_D18);
    }

    /// registerMarket()

    function testRegisterMarket() public {
        uint256 newMarketId = _createTonWethMarket();
        uint256 marketCountBefore = bondsController.internalMarketCount();

        vm.prank(address(TONTimelock));
        uint256 marketInternalId = bondsController.registerMarket(newMarketId);

        (
            uint256 marketId,
            IERC20 quoteToken,
            IERC20 payoutToken,
            uint256 marketPrice,
            uint256 vesting
        ) = _getMarketData(marketInternalId);

        uint256 marketCountAfter = bondsController.internalMarketCount();

        assertEq(newMarketId, marketId);
        assertEq(address(quoteToken), WETH_ADDRESS);
        assertEq(address(payoutToken), address(ton));
        assertEq(marketPrice, 8 * 10 ** 34);
        assertEq(vesting, VESTING_PERIOD);
        assertEq(marketCountAfter, marketCountBefore + 1);
    }

    function testCannotRegisterMarketNotLive() public {
        vm.expectRevert(abi.encodeWithSelector(MarketIsNotLive.selector));
        vm.prank(address(TONTimelock));
        bondsController.registerMarket(5);
    }

    function testCannotRegisterMarketNotTONTimelock() public {
        vm.expectRevert(abi.encodeWithSelector(NotTONTimelock.selector));
        vm.prank(user1);
        bondsController.registerMarket(0);
    }

    /// purchaseBond()

    function testPurchaseTonWethBond() public returns (uint256, uint256, uint256) {
        /// imitating WETH PRICE = 1250$, TON PRICE = $10

        uint256 newMarketInternalId = _registerMarket(_createTonWethMarket());
        uint256 purchaseAmount = ONE_D18;
        uint256 ownerWethBalanceBefore = weth.balanceOf(owner);

        (,,, uint256 marketPrice,) = _getMarketData(newMarketInternalId);

        vm.startPrank(user1);
        (uint256 payout, uint256 expiry) =
            bondsController.purchaseBond(newMarketInternalId, purchaseAmount, 0);
        vm.stopPrank();

        ERC20Solmate solmateTON = ERC20Solmate(address(ton));
        uint256 tokenId =
            IBondFixedTermTeller(address(teller)).getTokenId(solmateTON, uint48(expiry));

        uint256 balanceAfter = ERC1155(address(teller)).balanceOf(user1, tokenId);
        uint256 ownerWethBalanceAfter = weth.balanceOf(owner);

        /// maximum gap of 1 day since ERC1155 is determined by days and not seconds
        assertApproxEqAbs(expiry, block.timestamp + 7 days, 1 days);
        assertEq(
            payout * marketPrice / (10 ** (SCALED_DECIMALS + TON_SCALED_ADJUSTMENT)), purchaseAmount
        );
        assertEq(payout, balanceAfter);
        assertEq(ownerWethBalanceAfter, ownerWethBalanceBefore + purchaseAmount);

        return (newMarketInternalId, tokenId, payout);
    }

    function testPurchasePhoWethBond() public returns (uint256, uint256, uint256) {
        /// imitating WETH PRICE = 1250$, PHO PRICE = $1

        uint256 newMarketInternalId = _registerMarket(_createPhoWethMarket());
        uint256 purchaseAmount = ONE_D18;
        uint256 treasuryWethBalanceBefore = weth.balanceOf(address(treasury));
        (,,, uint256 bcPhoMintedBefore,,) = moduleManager.modules(address(bondsController));

        (,,, uint256 marketPrice,) = _getMarketData(newMarketInternalId);

        vm.startPrank(user1);
        (uint256 payout, uint256 expiry) =
            bondsController.purchaseBond(newMarketInternalId, purchaseAmount, 0);
        vm.stopPrank();

        ERC20Solmate solmatePHO = ERC20Solmate(address(pho));
        uint256 tokenId =
            IBondFixedTermTeller(address(teller)).getTokenId(solmatePHO, uint48(expiry));

        uint256 balanceAfter = ERC1155(address(teller)).balanceOf(user1, tokenId);
        uint256 treasuryWethBalanceAfter = weth.balanceOf(address(treasury));
        (,,, uint256 bcPhoMintedAfter,,) = moduleManager.modules(address(bondsController));

        /// maximum gap of 1 day since ERC1155 is determined by days and not seconds
        assertApproxEqAbs(expiry, block.timestamp + 7 days, 1 days);
        assertEq(payout * marketPrice / (10 ** (SCALED_DECIMALS + 1)), purchaseAmount);
        assertEq(payout, balanceAfter);
        assertEq(treasuryWethBalanceAfter, treasuryWethBalanceBefore + purchaseAmount);
        assertEq(bcPhoMintedAfter, bcPhoMintedBefore + payout);
        assertEq(phoCallback.totalUnbacked(), 0);

        return (newMarketInternalId, tokenId, payout);
    }

    function testCannotPurchaseBondMarketNotRegistered() public {
        vm.expectRevert(abi.encodeWithSelector(MarketNotRegistered.selector));
        vm.prank(user1);
        bondsController.purchaseBond(12, ONE_D18, 0);
    }

    /// redeemBond()

    function testRedeemTonWethBond() public {
        (uint256 internalMarketId, uint256 tokenId, uint256 amount) = testPurchaseTonWethBond();

        (,,,, uint256 vesting) = _getMarketData(internalMarketId);

        uint256 user1ERC1155BalanceBefore = ERC1155(address(teller)).balanceOf(user1, tokenId);
        uint256 user1TonBalanceBefore = ton.balanceOf(user1);
        uint256 bcTonBalanceBefore = ton.balanceOf(address(bondsController));

        vm.warp(block.timestamp + vesting);

        vm.startPrank(user1);
        ERC1155(address(teller)).setApprovalForAll(address(bondsController), true);
        bondsController.redeemBond(internalMarketId, tokenId, amount);
        vm.stopPrank();

        uint256 user1ERC1155BalanceAfter = ERC1155(address(teller)).balanceOf(user1, tokenId);
        uint256 user1TonBalanceAfter = ton.balanceOf(user1);
        uint256 bcTonBalanceAfter = ton.balanceOf(address(bondsController));

        assertEq(user1ERC1155BalanceAfter, user1ERC1155BalanceBefore - amount);
        assertEq(user1TonBalanceAfter, user1TonBalanceBefore + amount);
        assertEq(bcTonBalanceAfter, bcTonBalanceBefore);
    }

    function testRedeemPhoWethBond() public {
        (uint256 internalMarketId, uint256 tokenId, uint256 amount) = testPurchasePhoWethBond();

        (,,,, uint256 vesting) = _getMarketData(internalMarketId);

        uint256 user1ERC1155BalanceBefore = ERC1155(address(teller)).balanceOf(user1, tokenId);
        uint256 user1PhoBalanceBefore = pho.balanceOf(user1);

        vm.warp(block.timestamp + vesting);

        vm.startPrank(user1);
        ERC1155(address(teller)).setApprovalForAll(address(bondsController), true);
        bondsController.redeemBond(internalMarketId, tokenId, amount);
        vm.stopPrank();

        uint256 user1ERC1155BalanceAfter = ERC1155(address(teller)).balanceOf(user1, tokenId);
        uint256 user1PhoBalanceAfter = pho.balanceOf(user1);

        assertEq(user1ERC1155BalanceAfter, user1ERC1155BalanceBefore - amount);
        assertEq(user1PhoBalanceAfter, user1PhoBalanceBefore + amount);
    }

    function testCannotRedeemBondZeroValue() public {
        uint256 internalMarketId = _registerMarket(_createTonWethMarket());

        vm.expectRevert(abi.encodeWithSelector(ZeroValue.selector));
        bondsController.redeemBond(internalMarketId, 0, ONE_D18);

        vm.expectRevert(abi.encodeWithSelector(ZeroValue.selector));
        bondsController.redeemBond(internalMarketId, 1, 0);
    }

    function testCannotRedeemTonWethBondMarketNotRegistered() public {
        vm.expectRevert(abi.encodeWithSelector(MarketNotRegistered.selector));
        vm.prank(user1);
        bondsController.redeemBond(12, 1, 1);
    }

    /// test PHO-WETH market

    function _createNewMarket(
        address quoteToken,
        address payoutToken,
        address callbackAddress,
        uint256 capacity,
        uint256 initialPrice,
        uint256 minPrice,
        uint256 scaledAdjustment
    ) private returns (uint256) {
        bytes memory _params = abi.encode(
            ERC20(payoutToken),
            ERC20(quoteToken),
            callbackAddress,
            false,
            capacity,
            initialPrice,
            minPrice,
            10000,
            VESTING_PERIOD,
            block.timestamp + 4 weeks,
            1 hours,
            scaledAdjustment
        );
        vm.prank(owner);
        return auctioneer.createMarket(_params);
    }

    function _createTonWethMarket() private returns (uint256) {
        /// for params explanation:
        /// https://docs.bondprotocol.finance/smart-contracts/auctioneer/base-sequential-dutch-auctioneer-sda#marketparams
        ///  Creating the market based on TON and WETH prices mentioned above - WETH $1250 TON $10

        return _createNewMarket(
            WETH_ADDRESS,
            address(ton),
            address(0),
            10000000 * 10 ** 18,
            8 * 10 ** 34, // initial price gap
            5 * 10 ** 34, // min price gap
            TON_SCALED_ADJUSTMENT
        );
    }

    function _createPhoWethMarket() private returns (uint256) {
        /// for params explanation:
        /// https://docs.bondprotocol.finance/smart-contracts/auctioneer/base-sequential-dutch-auctioneer-sda#marketparams
        ///  Creating the market based on PHO and WETH prices - WETH $1250 PHO $1

        uint256 newMarketId = _createNewMarket(
            WETH_ADDRESS,
            address(pho),
            address(phoCallback),
            10000000 * 10 ** 18,
            8 * 10 ** 35, // initial price gap
            5 * 10 ** 35, // min price gap
            1
        );

        vm.startPrank(address(TONTimelock));
        phoCallback.updateQuoteOracle(newMarketId, address(priceOracle));
        phoCallback.whitelist(address(teller), newMarketId);
        vm.stopPrank();

        /// Set the correct ETH price
        priceOracle.setWethUSDPrice(1250 * 10 ** 18);

        return newMarketId;
    }

    function _registerMarket(uint256 marketId) private returns (uint256) {
        vm.prank(address(TONTimelock));
        return bondsController.registerMarket(marketId);
    }

    function _getMarketData(uint256 internalMarketId)
        private
        view
        returns (uint256, IERC20, IERC20, uint256, uint256)
    {
        (uint256 marketId, uint256 vesting,,,,, IERC20 quoteToken, IERC20 payoutToken,) =
            bondsController.markets(internalMarketId);

        uint256 marketPrice = auctioneer.marketPrice(marketId);

        return (marketId, quoteToken, payoutToken, marketPrice, vesting);
    }
}
