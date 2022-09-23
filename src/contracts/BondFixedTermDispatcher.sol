// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {BondBaseDispatcher} from "./BondBaseDispatcher.sol";
import {IBondFixedTermDispatcher} from "../interfaces/IBondFixedTermDispatcher.sol";
import {TransferHelper} from "./lib/TransferHelper.sol";
import {FullMath} from "../libraries/FullMath.sol";

/// @title Bond Fixed Term Dispatcher
/// @author Ekonomia: https://github.com/ekonomia-tech
/// @dev An implementation of the BondBaseDispatcher for bond markets with fixed term using ERC1155 tokens
contract BondFixedTermDispatcher is
    BondBaseDispatcher,
    IBondFixedTermDispatcher,
    ERC1155
{
    using TransferHelper for ERC20;
    using FullMath for uint256;

    /// Events
    event ERC1155BondTokenCreated(
        uint256 tokenId,
        ERC20 indexed payoutToken,
        uint48 indexed expiry
    );

    /// State vars
    mapping(uint256 => TokenMetadata) public tokenMetadata; // metadata for bond tokens

    /// Constructor
    constructor(address protocol_, address _controllerAddress)
        BondBaseDispatcher(protocol_, _controllerAddress)
    {}

    /// Purchase

    /// @notice handle payout to recipient
    /// @param recipient_ address to receive payout
    /// @param payout_ amount of payoutToken to be paid
    /// @param payoutToken_ token to be paid out
    /// @param vesting_ amount of time to vest from current timestamp
    /// @return expiry timestamp when the payout will vest
    function _handlePayout(
        address recipient_,
        uint256 payout_,
        ERC20 payoutToken_,
        uint48 vesting_
    ) internal override returns (uint48) {
        if (vesting_ != 0) {
            // normalizing fixed term vesting timestamps to the same time each day
            expiry =
                ((vesting_ + uint48(block.timestamp)) / uint48(1 days)) *
                uint48(1 days);

            // fixed-term user payout information is handled in BondDispatcher - mints ERC1155
            uint256 tokenId = getTokenId(payoutToken_, expiry);

            // create new bond token if it does not exist yet
            if (!tokenMetadata[tokenId].active) {
                _deploy(tokenId, payoutToken_, expiry);
            }

            // mint bond token to recipient
            _mintToken(recipient_, tokenId, payout_);
        } else {
            // if no expiry, then transfer payout directly to user
            payoutToken_.safeTransfer(recipient_, payout_);
        }
        return expiry;
    }

    /// Deposit / Mint

    /// @inheritdoc IBondFixedTermDispatcher
    function create(
        ERC20 underlying_,
        uint48 expiry_,
        uint256 amount_
    ) external override nonReentrant returns (uint256, uint256) {
        uint256 tokenId = getTokenId(underlying_, expiry_);

        // revert if no token exists, must call deploy first
        if (!tokenMetadata[tokenId].active)
            revert Dispatcher_TokenDoesNotExist(underlying_, expiry_);

        // transfer in underlying
        uint256 oldBalance = underlying_.balanceOf(address(this));
        underlying_.transferFrom(msg.sender, address(this), amount_);
        if (underlying_.balanceOf(address(this)) < oldBalance + amount_)
            revert Dispatcher_UnsupportedToken();

        // calculate fee and store it
        if (protocolFee > 0) {
            uint256 feeAmount = amount_.mulDiv(protocolFee, FEE_DECIMALS);
            rewards[_protocol][underlying_] += feeAmount;

            // mint new bond tokens
            _mintToken(msg.sender, tokenId, amount_ - feeAmount);
            return (tokenId, amount_ - feeAmount);
        } else {
            // mint new bond tokens
            _mintToken(msg.sender, tokenId, amount_);
            return (tokenId, amount_);
        }
    }

    /// Redeem
    function _redeem(uint256 tokenId_, uint256 amount_) internal {
        TokenMetadata memory meta = tokenMetadata[tokenId_];

        if (block.timestamp < meta.expiry)
            revert Dispatcher_TokenNotMatured(meta.expiry);

        _burnToken(msg.sender, tokenId_, amount_);
        meta.payoutToken.safeTransfer(msg.sender, amount_);
    }

    /// @inheritdoc IBondFixedTermDispatcher
    function redeem(uint256 tokenId_, uint256 amount_)
        public
        override
        nonReentrant
    {
        _redeem(tokenId_, amount_);
    }

    /// @inheritdoc IBondFixedTermDispatcher
    function batchRedeem(
        uint256[] calldata tokenIds_,
        uint256[] calldata amounts_
    ) external override nonReentrant {
        uint256 len = tokenIds_.length;
        for (uint256 i; i < len; ++i) {
            _redeem(tokenIds_[i], amounts_[i]);
        }
    }

    /// Tokenizing

    /// @inheritdoc IBondFixedTermDispatcher
    function deploy(ERC20 underlying_, uint48 expiry_)
        external
        override
        nonReentrant
        returns (uint256)
    {
        uint256 tokenId = getTokenId(underlying_, expiry_);
        // Only creates token if it does not exist
        if (!tokenMetadata[tokenId].active) {
            _deploy(tokenId, underlying_, expiry_);
        }
        return tokenId;
    }

    /// @notice deploy a new ERC1155 bond token and stores its ID
    /// @dev ERC1155 tokens used for fixed term bonds
    /// @param tokenId_ calculated ID of new bond token (from getTokenId)
    /// @param underlying_ underlying token to be paid out when the bond token vests
    /// @param expiry_ timestamp that the token will vest at
    function _deploy(
        uint256 tokenId_,
        ERC20 underlying_,
        uint48 expiry_
    ) internal {
        tokenMetadata[tokenId_] = TokenMetadata(true, underlying_, expiry_, 0);

        emit ERC1155BondTokenCreated(tokenId_, underlying_, expiry_);
    }

    /// @notice mint bond token and update supply
    /// @param to_ address to mint tokens to
    /// @param tokenId_ id of bond token to mint
    /// @param amount_ amount of bond tokens to mint
    function _mintToken(
        address to_,
        uint256 tokenId_,
        uint256 amount_
    ) internal {
        _mint(to_, tokenId_, amount_, bytes(""));
        tokenMetadata[tokenId_].supply += amount_;
    }

    /// @notice burn bond token and update supply
    /// @param from_ address to burn tokens from
    /// @param tokenId_ id of bond token to burn
    /// @param amount_ amount of bond token to burn
    function _burnToken(
        address from_,
        uint256 tokenId_,
        uint256 amount_
    ) internal {
        _burn(from_, tokenId_, amount_);
        tokenMetadata[tokenId_].supply -= amount_;
    }

    /// Token naming

    /// @inheritdoc IBondFixedTermDispatcher
    function getTokenId(ERC20 underlying_, uint48 expiry_)
        public
        pure
        override
        returns (uint256)
    {
        // vesting is divided by 1 day (in seconds) since bond tokens are only unique
        // to a day, not a specific timestamp
        uint256 tokenId = uint256(
            keccak256(abi.encodePacked(underlying_, expiry_ / uint48(1 days)))
        );
        return tokenId;
    }

    /// @inheritdoc IBondFixedTermDispatcher
    function getTokenNameAndSymbol(uint256 tokenId_)
        external
        view
        override
        returns (string memory, string memory)
    {
        TokenMetadata memory meta = tokenMetadata[tokenId_];
        (string memory name, string memory symbol) = _getNameAndSymbol(
            meta.payoutToken,
            meta.expiry
        );
        return (name, symbol);
    }
}
