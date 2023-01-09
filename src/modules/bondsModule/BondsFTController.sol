/// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "@protocol/interfaces/IModuleManager.sol";
import "@modules/bondsModule/interfaces/IBondsFTController.sol";
import "@modules/bondsModule/interfaces/IBondAggregator.sol";
import "@modules/bondsModule/interfaces/IBondAuctioneer.sol";
import "@modules/bondsModule/interfaces/IBondTeller.sol";
import "@modules/bondsModule/interfaces/IBondFixedTermTeller.sol";
import "@external/tokens/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Bonds Fixed Term Module
/// @notice This contracts is a module contract for purchasing a redeeming Bond Protocol Fixed Term bonds.
/// @author Ekonomia

contract BondsFTController is IBondsFTController {
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

    /// @notice constructor for BondsFTController
    /// @param _moduleManager the address of the module manager
    /// @param _tonTimelock TON Timelock contract address
    /// @param _treasury Protocol treasury contract address
    /// @param _aggregator Bond Protocol Aggregator.sol deployed contract address
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

    /// @notice Registers a market in this contract. Registration is meant for fast and efficient market data retrieval.
    /// @param marketId the Bond Protocol assigned market Id (Assigned upon market creation)
    /// @return internalMarketId A new market ID assigned by this contract that acts as an internal market ID
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

        emit FTMarketRegistered(
            address(auctioneer),
            address(quoteToken),
            address(payoutToken),
            marketId,
            newInternalMarketId
            );

        return newInternalMarketId;
    }

    /// @notice Purchase a bond for the caller. This function will allow purchasing bonds only from registered markets in this contract.
    /// @param internalMarketId An internal market ID assigned by the registerMarket() function
    /// @param amount the amount requested to purchase a bond with (in the market's quote token)
    /// @param minAmountOut Minimum amount of payout token out
    /// @return payout the amount of payout token to be received on bond redemption
    /// @return expiry the epoch time in which the bond expires and redemption is available
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
        (uint256 payout, uint256 expiry) =
            market.teller.purchase(msg.sender, treasury, market.marketId, amount, minAmountOut);

        uint256 tokenId = IBondFixedTermTeller(address(market.teller)).getTokenId(
            ERC20(address(market.payoutToken)), uint48(expiry)
        );

        emit FTBondPurchased(
            msg.sender, address(market.auctioneer), market.marketId, payout, expiry, tokenId
            );

        return (payout, expiry);
    }

    /// @notice Redeem an expired bond for the bond owner. Can only redeem bonds of markets that are registered in this contract
    /// @param internalMarketId An internal market ID assigned by the registerMarket() function
    /// @param tokenId The token that symbolizes the day of purchase and payout token. auto generated upon bond purchase
    /// @param amount the amount of payout token to be received on bond redemption
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

        emit FTBondRedeemed(
            msg.sender, address(market.auctioneer), market.marketId, amount, tokenId
            );
    }

    /// @notice mints $PHO for callback contract for market that the payout token in $PHO
    /// @param marketId the Bond Protocol assigned market Id. Passed as a control parameter to reassure that the market is indeed registered with this contract
    /// @param amount the amount of $PHO to be minted. determined by the bond payout amount
    function mintPHOForCallback(uint256 marketId, uint256 amount) external {
        MarketData memory market = markets[marketsInternalIds[marketId]];
        if (msg.sender != market.callbackContract) {
            revert CallerIsNotCallback();
        }
        moduleManager.mintPHO(address(market.teller), amount);
    }

    /// @notice Checks whether the market in question is in Live state on Bond Protocol contracts
    /// @param marketId the Bond Protocol assigned market Id
    /// @return isLive bool representation of whether the market is live or not
    function _isLive(uint256 marketId) private view returns (bool) {
        return aggregator.getAuctioneer(marketId).isLive(marketId);
    }

    /// @notice Function required to be implemented in order to transfer ERC1155 token into this contract.
    /// @dev this function is called by the ERC1155 safeTransferFrom() function that is implemented by the market related teller contract
    /// @return selector returns the selector of this function
    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return ERC1155TokenReceiver.onERC1155Received.selector;
    }

    /// @notice Function required to be implemented in order to transfer ERC1155 token into this contract
    /// @dev this function is called by the ERC1155 safeBatchTransferFrom() function that is implemented by the market related teller contract
    /// @return selector returns the selector of this function
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
