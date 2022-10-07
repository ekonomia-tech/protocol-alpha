// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "./BaseSetup.t.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/contracts/BondFixedExpiryModule.sol";
import "src/contracts/BondBaseModule.sol";
import "src/interfaces/IBondModule.sol";
import "src/contracts/ERC20BondToken.sol";

contract BondModuleTest is BaseSetup {
    // Contract relevant test constants
    address public protocol = 0xe688b84b23f322a994A53dbF8E15FA82CDB71127;
    BondFixedExpiryModule public bondFixedExpiryModule;

    // Structs
    struct MarketParams {
        ERC20 payoutToken; // payout token
        ERC20 quoteToken; // quote token
        uint256 capacity; // capacity (in payout token)
        uint256 initialPrice; // initial price
        uint256 maxDiscount; // max discount on initial price
        uint256 termStart; // start
        uint256 termEnd; // end
    }

    struct BondMarket {
        ERC20 payoutToken; // payout token that bonders receive - PHO or TON
        ERC20 quoteToken; // quote token that bonders deposit
        uint256 capacity; // capacity (in payout token)
        uint256 initialPrice; // initial price
        uint256 maxDiscount; // max discount on initial price
        uint256 termStart; // start
        uint256 termEnd; // end
        uint256 totalDebt; // total payout token debt from market
        uint256 sold; // payout tokens out
        uint256 purchased; // quote tokens in
    }

    uint48 internal constant FEE_DECIMALS = 10 ** 5;

    function setUp() public {
        vm.prank(owner);
        bondFixedExpiryModule = new BondFixedExpiryModule(
            controller,
            address(pho),
            address(usdc),
            protocol
        );

        // User -> sends USDC to module
        // Bond controller sends PHO to module
        vm.prank(owner);
        teller.whitelistCaller(address(bondFixedExpiryModule), 200 * ONE_MILLION_D18);
        vm.prank(address(bondFixedExpiryModule));
        teller.mintPHO(address(bondFixedExpiryModule), ONE_MILLION_D18);

        // User1 gets TON and approves sending to BondModule
        _getTON(user1, TEN_THOUSAND_D18);
        vm.prank(user1);
        ton.approve(address(bondFixedExpiryModule), 100 * TEN_THOUSAND_D18);

        // Approval for bondController sending PHO to BondModule
        vm.prank(address(bondFixedExpiryModule));
        pho.approve(address(bondFixedExpiryModule), 100 * ONE_MILLION_D18);

        // User1 gets TON and approves sending to BondModule
        _getUSDC(user1, TEN_THOUSAND_D6);
        vm.prank(user1);
        ERC20(address(usdc)).approve(address(bondFixedExpiryModule), 100 * TEN_THOUSAND_D6);
    }

    /// Creating BondModule

    // Cannot create BondModule with zero address
    function testCannotCreateBondModuleZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(BondBaseModule.ZeroAddressDetected.selector));
        vm.prank(owner);
        bondFixedExpiryModule = new BondFixedExpiryModule(
            address(bondFixedExpiryModule),
            address(0),
            address(pho),
            address(usdc)
        );

        vm.expectRevert(abi.encodeWithSelector(BondBaseModule.ZeroAddressDetected.selector));
        vm.prank(owner);
        bondFixedExpiryModule = new BondFixedExpiryModule(
            address(bondFixedExpiryModule),
            address(controller),
            address(0),
            address(usdc)
        );

        vm.expectRevert(abi.encodeWithSelector(BondBaseModule.ZeroAddressDetected.selector));
        vm.prank(owner);
        bondFixedExpiryModule = new BondFixedExpiryModule(
            address(bondFixedExpiryModule),
            address(controller),
            address(pho),
            address(0)
        );
    }

    /// createMarket()

    // Cannot create if not owner/controller
    function testCannotCreateMarketOnlyOwnerModule() public {
        MarketParams memory params = MarketParams({
            payoutToken: pho,
            quoteToken: ERC20(address(usdc)),
            capacity: 10 ** 18,
            initialPrice: 10 ** 6,
            maxDiscount: 10 ** 4,
            termStart: 1000000000,
            termEnd: 20000000000
        });
        vm.expectRevert("BondModule: not the owner or controller");
        vm.prank(user1);
        bondFixedExpiryModule.createMarket(abi.encode(params));
    }

    // Cannot use invalid params for createMarket()
    function testCannotCreateMarketInvalidParams() public {
        // payout token not PHO or TON
        MarketParams memory params = MarketParams({
            payoutToken: ERC20(address(fraxBPLP)),
            quoteToken: ERC20(address(usdc)),
            capacity: 10 ** 18,
            initialPrice: 10 ** 6,
            maxDiscount: 10 ** 4,
            termStart: 1000000000,
            termEnd: 20000000000
        });
        vm.expectRevert(abi.encodeWithSelector(BondBaseModule.PayoutTokenPHOorTON.selector));
        vm.prank(owner);
        bondFixedExpiryModule.createMarket(abi.encode(params));

        // params.termEnd < params.termStart
        params = MarketParams({
            payoutToken: pho,
            quoteToken: ERC20(address(usdc)),
            capacity: 10 ** 18,
            initialPrice: 10 ** 4,
            maxDiscount: 10 ** 5,
            termStart: 1000000000,
            termEnd: 1000000000 - 1
        });
        vm.expectRevert(abi.encodeWithSelector(BondBaseModule.CreateMarketInvalidParams.selector));
        vm.prank(owner);
        bondFixedExpiryModule.createMarket(abi.encode(params));
    }

    // Test basic createMarket, checking BondMarket struct
    function testCreateMarketBasicBondMarket() public {
        MarketParams memory params = MarketParams({
            payoutToken: pho,
            quoteToken: ERC20(address(usdc)),
            capacity: 10 ** 18,
            initialPrice: 10 ** 6,
            maxDiscount: 10 ** 4,
            termStart: 1000000000,
            termEnd: 20000000000
        });
        vm.prank(owner);
        bondFixedExpiryModule.createMarket(abi.encode(params));

        // Bond market
        (
            ERC20 payoutToken,
            ERC20 quoteToken,
            uint256 capacity,
            uint256 initialPrice,
            uint256 maxDiscount,
            uint256 termStart,
            uint256 termEnd,
            uint256 totalDebt,
            uint256 sold,
            uint256 purchased
        ) = bondFixedExpiryModule.markets(0);

        assertEq(address(payoutToken), address(pho));
        assertEq(address(quoteToken), address(usdc));
        assertEq(capacity, params.capacity);
        assertEq(initialPrice, params.initialPrice);
        assertEq(maxDiscount, params.maxDiscount);
        assertEq(termStart, params.termStart);
        assertEq(termEnd, params.termEnd);
        assertEq(totalDebt, 0);
        assertEq(sold, 0);
        assertEq(purchased, 0);
    }

    /// Close market

    // Cannot closeMarket if not owner/controller
    function testCannotCloseMarketOnlyOwnerModule() public {
        vm.expectRevert("BondModule: not the owner or controller");
        vm.prank(user1);
        bondFixedExpiryModule.closeMarket(0);
    }

    // Basic setDefaults
    function testCloseMarket() public {
        MarketParams memory params = MarketParams({
            payoutToken: pho,
            quoteToken: ERC20(address(usdc)),
            capacity: 10 ** 18,
            initialPrice: 10 ** 6,
            maxDiscount: 10 ** 4,
            termStart: 1000000000,
            termEnd: 20000000000
        });
        vm.prank(owner);
        bondFixedExpiryModule.createMarket(abi.encode(params));

        vm.prank(owner);
        bondFixedExpiryModule.closeMarket(0);

        //(, , , uint256 termEnd) = bondFixedExpiryModule.terms(0);
        (,, uint256 capacity,,,,,,,) = bondFixedExpiryModule.markets(0);

        //assertEq(termEnd, block.timestamp);
        assertEq(capacity, 0);
    }

    // Purchase bond

    // Cannot purchase bond if past termEnd
    function testCannotPurchaseBondAfterConclusion() public {
        uint256 amount = 100000;
        MarketParams memory params = MarketParams({
            payoutToken: pho,
            quoteToken: ERC20(address(usdc)),
            capacity: 10 ** 18,
            initialPrice: 10 ** 6,
            maxDiscount: 10 ** 4,
            termStart: 1000000000,
            termEnd: block.timestamp + 2 days
        });
        vm.prank(owner);
        bondFixedExpiryModule.createMarket(abi.encode(params));

        vm.warp(block.timestamp + 2 days + 1);

        vm.expectRevert(abi.encodeWithSelector(BondBaseModule.PurchaseWindowPassed.selector));
        vm.prank(address(bondFixedExpiryModule));
        bondFixedExpiryModule.purchaseBond(0, amount);
    }

    /// Basic purchaseBond
    function testPurchaseBondBasic() public {
        uint256 amount = ONE_THOUSAND_D6;
        MarketParams memory params = MarketParams({
            payoutToken: pho,
            quoteToken: ERC20(address(usdc)),
            capacity: 10 ** 18,
            initialPrice: 10 ** 6,
            maxDiscount: 10 ** 4,
            termStart: block.timestamp,
            termEnd: block.timestamp + 2 days
        });
        vm.prank(owner);
        bondFixedExpiryModule.createMarket(abi.encode(params));

        vm.prank(address(bondFixedExpiryModule));
        bondFixedExpiryModule.purchaseBond(0, amount);

        (,, uint256 capacity,,,,, uint256 totalDebt, uint256 sold, uint256 purchased) =
            bondFixedExpiryModule.markets(0);

        assertEq(purchased, amount);
    }

    /// Setting protocol fees

    // Cannot set protocol fee if not owner/controller
    function testCannotSetProtocolFeeOnlyOwnerController() public {
        uint48 newFee = 500;
        vm.expectRevert("BondModule: not the owner or controller");
        vm.prank(user1);
        bondFixedExpiryModule.setProtocolFee(newFee);
    }

    // Basic set protocol fee
    function testSetProtocolFee() public {
        uint48 newFee = 500;
        vm.prank(owner);
        bondFixedExpiryModule.setProtocolFee(newFee);
        assertEq(bondFixedExpiryModule.protocolFee(), newFee);
    }

    /// Registering market

    // Cannot register market if not owner/controller
    function testCannotRegisterMarketOnlyOwnerController() public {
        address newBondController = 0xDAFEA492D9c6733ae3d56b7Ed1ADB60692c98Bc5;
        vm.expectRevert("BondModule: not the owner or controller");
        vm.prank(user1);
        bondFixedExpiryModule.registerMarket(ERC20(pho), ERC20(address(usdc)));
    }

    // Basic set register market
    function testRegisterMarket() public {
        vm.prank(owner);
        bondFixedExpiryModule.registerMarket(ERC20(pho), ERC20(address(usdc)));
        assertEq(bondFixedExpiryModule.marketCounter(), 1);
        assertEq(bondFixedExpiryModule.marketsForPayout(address(pho), 0), 0);
        assertEq(bondFixedExpiryModule.marketsForQuote(address(usdc), 0), 0);
    }

    /// Claim fees

    // Cannot claim fees if not owner/controller
    function testCannotClaimFeesOnlyOwnerController() public {
        ERC20[] memory tokens = new ERC20[](1);
        tokens[0] = pho;
        vm.expectRevert("BondModule: not the owner or controller");
        vm.prank(user1);
        bondFixedExpiryModule.claimFees(tokens, user1);
    }

    // Basic claim of 0 fees
    function testClaimZeroFees() public {
        ERC20[] memory tokens = new ERC20[](1);
        tokens[0] = pho;
        uint256 phoBalanceOwnerBefore = pho.balanceOf(address(owner));
        vm.prank(owner);
        bondFixedExpiryModule.claimFees(tokens, address(user1));
        // 0 fees
        assertEq(pho.balanceOf(address(owner)), phoBalanceOwnerBefore);
    }

    /// Purchase

    // Basic purchase
    function testPurchase() public {
        address recipient = user1;
        uint256 marketId = 0;
        uint256 amount = ONE_THOUSAND_D6;
        uint256 termStart = block.timestamp;
        uint256 termEnd = block.timestamp + 2 days;

        MarketParams memory params = MarketParams({
            payoutToken: pho,
            quoteToken: ERC20(address(usdc)),
            capacity: 10 ** 18,
            initialPrice: 10 ** 6, // 1:1 with PHO for USDC
            maxDiscount: 2 * 10 ** 5, // 10**6 = 100%, 2*10**5 = 20%
            termStart: termStart,
            termEnd: termEnd
        });
        vm.prank(owner);
        bondFixedExpiryModule.createMarket(abi.encode(params));

        ERC20BondToken bond = bondFixedExpiryModule.bondTokens(pho, termEnd);

        vm.warp(block.timestamp + 1 days);

        uint256 userQuoteTokenBalanceBeforePurchase = ERC20(address(usdc)).balanceOf(user1);
        uint256 userBondTokenBalanceBeforePurchase = ERC20(address(bond)).balanceOf(user1);

        // 50% of maxDiscount -> adjustedDiscount is 10**5
        // price factor is 1 since initialPrice * (10**12) == 10**18
        // payout = amount * 1 * ((10**6 + 10**5) / 10**6) = 1.1 * amount
        vm.prank(user1);
        (uint256 payout, uint256 expiry) =
            bondFixedExpiryModule.purchase(recipient, marketId, amount);

        // Check payout
        uint256 expectedPayout = (11 * 10 ** 6 * amount) / (10 * 10 ** 6);
        assertEq(payout, expectedPayout);

        // check balances
        uint256 userQuoteTokenBalanceAfterPurchase = ERC20(address(usdc)).balanceOf(user1);
        uint256 userBondTokenBalanceAfterPurchase = ERC20(address(bond)).balanceOf(user1);
        assertEq(userQuoteTokenBalanceBeforePurchase - userQuoteTokenBalanceAfterPurchase, amount);
        assertEq(
            userBondTokenBalanceAfterPurchase - userBondTokenBalanceBeforePurchase, expectedPayout
        );
    }

    /// Specific to BondFixedExpiryModule

    /// deploy()

    /// Basic example for deploy
    function testDeploy() public {
        uint256 termEnd = block.timestamp + 100000;
        vm.prank(owner);
        bondFixedExpiryModule.deploy(pho, termEnd);

        ERC20BondToken bond = bondFixedExpiryModule.bondTokens(pho, termEnd);
        assertEq(address(bond.payoutToken()), address(pho));
        assertEq(bond.termEnd(), termEnd);
        assertEq(address(bondFixedExpiryModule.bondTokens(pho, termEnd)), address(bond));
    }

    /// create()

    /// redeem()

    function testBasicRedeem() public {
        address recipient = user1;
        uint256 marketId = 0;
        uint256 amount = ONE_THOUSAND_D6;
        uint256 termStart = block.timestamp;
        uint256 termEnd = block.timestamp + 2 days;

        MarketParams memory params = MarketParams({
            payoutToken: pho,
            quoteToken: ERC20(address(usdc)),
            capacity: 10 ** 18,
            initialPrice: 10 ** 6, // 1:1 with PHO for USDC
            maxDiscount: 2 * 10 ** 5, // 10**6 = 100%, 2*10**5 = 20%
            termStart: termStart,
            termEnd: termEnd
        });
        vm.prank(owner);
        bondFixedExpiryModule.createMarket(abi.encode(params));

        ERC20BondToken bond = bondFixedExpiryModule.bondTokens(pho, termEnd);

        vm.warp(block.timestamp + 1 days);

        // 50% of maxDiscount -> adjustedDiscount is 10**5
        // price factor is 1 since initialPrice * (10**12) == 10**18
        // payout = amount * 1 * ((10**6 + 10**5) / 10**6) = 1.1 * amount
        vm.prank(user1);
        (uint256 payout, uint256 expiry) =
            bondFixedExpiryModule.purchase(recipient, marketId, amount);

        // Check payout
        uint256 expectedPayout = (11 * 10 ** 6 * amount) / (10 * 10 ** 6);
        assertEq(payout, expectedPayout);

        vm.warp(termEnd);

        uint256 userPayoutTokenBalanceBeforeRedeem = pho.balanceOf(user1);
        uint256 userBondTokenBalanceBeforeRedeem = ERC20(address(bond)).balanceOf(user1);

        vm.prank(user1);
        bondFixedExpiryModule.redeem(bond, expectedPayout);

        // check balances
        uint256 userPayoutTokenBalanceAfterRedeem = pho.balanceOf(user1);
        uint256 userBondTokenBalanceAfterRedeem = ERC20(address(bond)).balanceOf(user1);
        assertEq(
            userPayoutTokenBalanceAfterRedeem - userPayoutTokenBalanceBeforeRedeem, expectedPayout
        );
        assertEq(userBondTokenBalanceBeforeRedeem - userBondTokenBalanceAfterRedeem, expectedPayout);
    }
}
