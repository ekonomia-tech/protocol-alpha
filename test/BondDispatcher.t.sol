// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "./BaseSetup.t.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "src/contracts/BondBaseDispatcher.sol";
import "src/contracts/BondFixedExpiryDispatcher.sol";
import "src/contracts/BondFixedExpiryController.sol";
import "src/contracts/BondBaseController.sol";

contract BondDispatcherTest is BaseSetup {
    address public protocol = 0xe688b84b23f322a994A53dbF8E15FA82CDB71127;
    BondFixedExpiryDispatcher public bondFixedExpiryDispatcher;
    BondFixedExpiryController public bondFixedExpiryController;

    // Structs
    struct MarketParams {
        ERC20 payoutToken; // payout token
        ERC20 quoteToken; // quote token
        uint256 capacity; // capacity
        uint256 formattedInitialPrice; // initial price
        uint256 formattedMinimumPrice; // min price
        uint48 vesting; // if fixed term then vesting length otherwise vesting expiry timestamp
        uint48 conclusion; // conclusion timestamp
        uint32 depositInterval; // deposit interval
        int8 scaleAdjustment; // scale adjustment
    }

    function setUp() public {
        vm.prank(owner);
        bondFixedExpiryDispatcher = new BondFixedExpiryDispatcher(
            protocol,
            controller
        );

        // Payout token: PHO, quote token: USDC
        vm.prank(owner);
        bondFixedExpiryController = new BondFixedExpiryController(
            address(bondFixedExpiryDispatcher),
            controller,
            address(pho),
            address(ton)
        );

        // User -> sends USDC to dispatcher (who sends to controller)
        // Bond controller sends PHO to dispatcher
        vm.prank(owner);
        teller.whitelistCaller(address(bondFixedExpiryController), 200 * tenThousand_d18);
        vm.prank(address(bondFixedExpiryController));
        teller.mintPHO(address(bondFixedExpiryController), tenThousand_d18);

        // User1 gets TON and approves sending to BondDispatcher
        _getTON(user1, tenThousand_d18);
        vm.prank(user1);
        ton.approve(address(bondFixedExpiryDispatcher), 100 * tenThousand_d18);

        // Approval for bondController sending PHO to BondDispatcher
        vm.prank(address(bondFixedExpiryController));
        pho.approve(address(bondFixedExpiryDispatcher), 100 * tenThousand_d18);
    }

    /// Setting protocol fees

    // Cannot set protocol fee if not owner/controller
    function testCannotSetProtocolFeeOnlyOwnerController() public {
        uint48 newFee = 500;
        vm.expectRevert("BondDispatcher: not the owner or controller");
        vm.prank(user1);
        bondFixedExpiryDispatcher.setProtocolFee(newFee);
    }

    // Basic set protocol fee
    function testSetProtocolFee() public {
        uint48 newFee = 500;
        vm.prank(owner);
        bondFixedExpiryDispatcher.setProtocolFee(newFee);
        assertEq(bondFixedExpiryDispatcher.protocolFee(), newFee);
    }

    /// Setting bond controller

    // Cannot set bond controller if not owner/controller
    function testCannotSetBondControllerOnlyOwnerController() public {
        address newBondController = 0xDAFEA492D9c6733ae3d56b7Ed1ADB60692c98Bc5;
        vm.expectRevert("BondDispatcher: not the owner or controller");
        vm.prank(user1);
        bondFixedExpiryDispatcher.setBondController(newBondController);
    }

    // Basic set bond controller
    function testSetBondController() public {
        address newBondController = 0xDAFEA492D9c6733ae3d56b7Ed1ADB60692c98Bc5;
        vm.prank(owner);
        bondFixedExpiryDispatcher.setBondController(newBondController);
        assertEq(bondFixedExpiryDispatcher.bondController(), newBondController);
    }

    /// Registering market

    // Cannot register market if not owner/controller
    function testCannotRegisterMarketOnlyOwnerController() public {
        address newBondController = 0xDAFEA492D9c6733ae3d56b7Ed1ADB60692c98Bc5;
        vm.expectRevert("BondDispatcher: not the owner or controller");
        vm.prank(user1);
        bondFixedExpiryDispatcher.registerMarket(ERC20(pho), ERC20(ton));
    }

    // Basic set register market
    function testRegisterMarket() public {
        vm.prank(owner);
        bondFixedExpiryDispatcher.registerMarket(ERC20(pho), ERC20(ton));
        assertEq(bondFixedExpiryDispatcher.marketCounter(), 1);
        assertEq(bondFixedExpiryDispatcher.marketsForPayout(address(pho), 0), 0);
        assertEq(bondFixedExpiryDispatcher.marketsForQuote(address(ton), 0), 0);
    }

    /// Claim fees

    // Cannot claim fees if not owner/controller
    function testCannotClaimFeesOnlyOwnerController() public {
        ERC20[] memory tokens = new ERC20[](1);
        tokens[0] = pho;
        vm.expectRevert("BondDispatcher: not the owner or controller");
        vm.prank(user1);
        bondFixedExpiryDispatcher.claimFees(tokens, user1);
    }

    // Basic claim of 0 fees
    function testClaimZeroFees() public {
        ERC20[] memory tokens = new ERC20[](1);
        tokens[0] = pho;
        uint256 phoBalanceOwnerBefore = pho.balanceOf(address(owner));
        vm.prank(owner);
        bondFixedExpiryDispatcher.claimFees(tokens, address(user1));
        // 0 fees
        assertEq(pho.balanceOf(address(owner)), phoBalanceOwnerBefore);
    }

    /// Purchase

    // Cannot purchase if bondController is address(0)
    function testCannotPurchaseIfBondControllerZero() public {
        address recipient = user1;
        uint256 marketId = 0;
        uint256 amount = 100000;
        uint256 minAmountOut = 50000;
        vm.expectRevert("BondDispatcher: zero address detected");
        vm.prank(owner);
        bondFixedExpiryDispatcher.purchase(recipient, marketId, amount, minAmountOut);
    }

    // Basic purchase - TODO: enable transfers
    function testPurchase() public {
        address recipient = user1;
        uint256 marketId = 0;
        uint256 amount = 10000;
        uint256 minAmountOut = 5000;

        vm.prank(owner);
        bondFixedExpiryDispatcher.setBondController(address(bondFixedExpiryController));

        MarketParams memory params = MarketParams({
            payoutToken: pho,
            quoteToken: ton,
            capacity: 10 ** 18,
            formattedInitialPrice: 10 ** 6,
            formattedMinimumPrice: 10 ** 4,
            vesting: 1000000000,
            conclusion: 10000000000,
            depositInterval: 24 hours,
            scaleAdjustment: 10
        });
        vm.prank(owner);
        bondFixedExpiryController.createMarket(abi.encode(params));

        vm.prank(user1);
        bondFixedExpiryDispatcher.purchase(recipient, marketId, amount, minAmountOut);
    }

    /// Specific to BondFixedExpiryDispatcher

    /// Basic example for deploy
    function testDeploy() public {
        uint48 expiry = uint48(block.timestamp + 100000);
        vm.prank(owner);
        bondFixedExpiryDispatcher.deploy(ton, expiry);

        ERC20BondToken bond = bondFixedExpiryDispatcher.bondTokens(ton, expiry);
        assertEq(address(bond.underlying()), address(ton));
        assertEq(bond.expiry(), expiry);
    }

    /// create()

    /// deploy()
}
