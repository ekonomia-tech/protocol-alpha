// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IBondDispatcher {
    /// Events
    event Bonded(uint256 indexed id, uint256 amount, uint256 payout);

    /// @notice exchange quote tokens for a bond in a specified market
    /// @param recipient_ depositor address
    /// @param marketId bond market id
    /// @param amount_ amount to deposit in exchange for bond
    /// @param minAmountOut_ min acceptable amount of bond to receive. Prevents frontrunning
    /// @return amount amount of payout token to be received from the bond
    /// @return timestamp when bond token can be redeemed for underlying
    function purchase(
        address recipient_,
        uint256 marketId,
        uint256 amount_,
        uint256 minAmountOut_
    ) external returns (uint256, uint48);

    /// @notice current fee charged by the dispatcher based on the protocol fee
    /// @return fee in bps (3 decimal places)
    function getFee() external view returns (uint48);

    /// @notice set protocol fee
    /// @param fee_ protocol fee in basis points (3 decimal places)
    function setProtocolFee(uint48 fee_) external;

    /// @notice set bond controller
    /// @param _bondController address for bond controller
    function setBondController(address _bondController) external;

    /// @notice register a new market
    /// @param payoutToken_ token to be paid out by the market
    /// @param quoteToken_ token to be accepted by the market
    /// @param marketId id of the market being created
    function registerMarket(ERC20 payoutToken_, ERC20 quoteToken_)
        external
        returns (uint256 marketId);

    /// @notice claim fees accrued for input tokens and sends to protocol
    /// @param tokens_ array of tokens to claim fees for
    /// @param to_ address to send fees to
    function claimFees(ERC20[] memory tokens_, address to_) external;
}
