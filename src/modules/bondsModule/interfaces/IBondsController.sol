/// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@modules/bondsModule/interfaces/IBondAuctioneer.sol";
import "@modules/bondsModule/interfaces/IBondTeller.sol";
import "@external/tokens/ERC1155.sol";

interface IBondsController is ERC1155TokenReceiver {
    error ZeroAddress();
    error ZeroValue();
    error NotTONTimelock();
    error MarketIsNotLive();
    error MarketNotRegistered();
    error NoBalanceAvailable();
    error TellerMismatch();
    error CallerIsNotCallback();

    struct MarketData {
        uint256 marketId;
        uint256 expiry;
        address owner;
        address callbackContract;
        IBondAuctioneer auctioneer;
        IBondTeller teller;
        IERC20 quoteToken;
        IERC20 payoutToken;
        bool isFixedTerm;
    }

    function registerMarket(uint256 marketId) external returns (uint256);
    function purchaseBond(uint256 internalMarketId, uint256 amount, uint256 minAmountOut)
        external
        returns (uint256, uint256);
    function redeemBond(uint256 internalMarketId, uint256 tokenId, uint256 amount) external;
    function mintPHOForCallback(address to, uint256 marketId, uint256 amount) external;
}
