/// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "@protocol/interfaces/IModuleManager.sol";
import "@modules/bondsModule/interfaces/IBondsController.sol";
import "@modules/bondsModule/interfaces/IBondAggregator.sol";
import "@modules/bondsModule/interfaces/IBondAuctioneer.sol";
import "@modules/bondsModule/interfaces/IBondTeller.sol";
import "@modules/bondsModule/interfaces/IBondFixedTermTeller.sol";
import "@external/tokens/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// Thoughts:
/// 1. Do we need to emit event on BondPurchased and BondRedeemed? Bond protocol already emits these events.
/// 2. Should we rely on the subgraphs by Bond Protocol or should we build our own graph to track them?

contract BondsController is IBondsController {
    // internal market ID to bond protocol market data
    mapping(uint256 => MarketData) public markets;

    // Bond protocol market ID to internal market id
    mapping(uint256 => uint256) public marketsInternalIds;

    // Counter to track the amount of markets
    uint256 public internalMarketCount;

    // vesting time limit set by bond protocol. any vesting above that is considered expiry date
    uint256 private constant VESTING_LIMIT = 50 * 365 days;

    // TON Timelock address
    address public TONTimelock;

    // Treasury address
    address public treasury;

    // Bond protocol aggregator
    IBondAggregator public aggregator;

    // Module manager
    IModuleManager public moduleManager;

    modifier onlyTONTimelock() {
        if (msg.sender != TONTimelock) revert NotTONTimelock();
        _;
    }

    constructor(
        address _moduleManager,
        address _tonTimelock,
        address _treasury,
        address _aggregator
    ) {
        if (
            _moduleManager == address(0) || _tonTimelock == address(0) || _aggregator == address(0)
                || _treasury == address(0)
        ) {
            revert ZeroAddress();
        }
        moduleManager = IModuleManager(_moduleManager);
        TONTimelock = _tonTimelock;
        treasury = _treasury;
        aggregator = IBondAggregator(_aggregator);
    }

    function registerMarket(uint256 marketId) external onlyTONTimelock returns (uint256) {
        if (!_isLive(marketId)) revert MarketIsNotLive();

        IBondAuctioneer auctioneer = aggregator.getAuctioneer(marketId);
        IBondTeller teller = aggregator.getTeller(marketId);

        (address owner, address callbackAddr, ERC20 payoutToken, ERC20 quoteToken, uint256 vesting,)
        = auctioneer.getMarketInfoForPurchase(marketId);

        uint256 newInternalMarketId = internalMarketCount;

        markets[newInternalMarketId] = MarketData(
            marketId,
            vesting,
            owner,
            callbackAddr,
            auctioneer,
            teller,
            IERC20(address(quoteToken)),
            IERC20(address(payoutToken)),
            vesting >= VESTING_LIMIT
        );

        marketsInternalIds[marketId] = newInternalMarketId;

        internalMarketCount++;

        return newInternalMarketId;
    }

    function purchaseBond(uint256 internalMarketId, uint256 amount, uint256 minAmountOut)
        external
        returns (uint256, uint256)
    {
        MarketData memory market = markets[internalMarketId];

        if (address(market.quoteToken) == address(0)) revert MarketNotRegistered();
        if (!_isLive(market.marketId)) revert MarketIsNotLive();

        /// transfer user funds
        market.quoteToken.transferFrom(msg.sender, address(this), amount);
        market.quoteToken.approve(address(market.teller), amount);

        /// purchase the bond
        return market.teller.purchase(msg.sender, treasury, market.marketId, amount, minAmountOut);
    }

    function redeemBond(uint256 internalMarketId, uint256 tokenId, uint256 amount) external {
        if (tokenId == 0 || amount == 0) revert ZeroValue();
        MarketData memory market = markets[internalMarketId];

        if (address(market.quoteToken) == address(0)) revert MarketNotRegistered();

        /// transfer the ERC1155 tokens to this contract
        ERC1155(address(market.teller)).safeTransferFrom(
            msg.sender, address(this), tokenId, amount, bytes("")
        );

        /// redeem the bond tokens
        IBondFixedTermTeller(address(market.teller)).redeem(tokenId, amount);

        /// pay out to the user
        market.payoutToken.transfer(msg.sender, amount);
    }

    function mintPHOForCallback(address to, uint256 marketId, uint256 amount) external {
        MarketData memory market = markets[marketsInternalIds[marketId]];
        if (msg.sender != market.callbackContract || msg.sender.code.length == 0) {
            revert CallerIsNotCallback();
        }
        if (address(market.teller) == address(0)) revert MarketNotRegistered();
        if (address(market.teller) != to) revert TellerMismatch();
        moduleManager.mintPHO(address(market.teller), amount);
    }

    function _isLive(uint256 marketId) private view returns (bool) {
        return aggregator.getAuctioneer(marketId).isLive(marketId);
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return ERC1155TokenReceiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }
}
