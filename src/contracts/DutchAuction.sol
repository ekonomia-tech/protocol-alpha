// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title Dutch Auction
/// @notice General dutch auction
contract DutchAuction is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    /// @notice Market info
    struct MarketInfo {
        uint256 startTime;
        uint256 endTime;
        uint256 totalTokens;
    }

    /// @notice Market price
    struct MarketPrice {
        uint256 startPrice;
        uint256 minPrice;
    }

    /// @notice Market status
    struct MarketStatus {
        uint256 commitmentsTotal;
        bool finalized;
    }

    /// Structs
    MarketInfo public marketInfo;
    MarketPrice public marketPrice;
    MarketStatus public marketStatus;
    mapping(address => uint256) public commitments;
    mapping(address => uint256) public claimed;

    /// Tokens
    IERC20 public auctionToken;
    IERC20 public paymentToken;

    uint8 private PAYMENT_TOKEN_DECIMALS;
    uint8 private constant AUCTION_TOKEN_DECIMALS = 18;

    /// Events
    event AddedCommitment(
        address indexed buyer,
        address indexed auctionToken,
        address indexed paymentToken,
        uint256 commitment,
        uint256 decimals
    );
    event ModifiedAuctionParams(
        address indexed owner,
        address indexed auctionToken,
        address indexed paymentToken,
        uint256 newStartTime,
        uint256 newEndTime,
        uint256 newStartPrice,
        uint256 newMinPrice
    );

    /// @notice Initializes auction with params
    /// @dev Params: tokens, start/end times, start/min price
    function initAuction(
        address _auctionToken,
        address _paymentToken,
        uint256 _totalTokens,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _startPrice,
        uint256 _minPrice
    )
        public
        onlyOwner
    {
        require(_startTime >= block.timestamp, "DutchAuction: start time must be > current time");
        require(_endTime > _startTime, "DutchAuction: end time must be > start time");
        require(_totalTokens > 0, "DutchAuction: total tokens must be > zero");
        require(_startPrice > _minPrice, "DutchAuction: start price must be > min price");
        require(_minPrice > 0, "DutchAuction: minimum price must be greater than 0");

        auctionToken = IERC20(_auctionToken);
        paymentToken = IERC20(_paymentToken);
        marketInfo.startTime = _startTime;
        marketInfo.endTime = _endTime;
        marketInfo.totalTokens = _totalTokens;
        marketPrice.startPrice = _startPrice;
        marketPrice.minPrice = _minPrice;
        PAYMENT_TOKEN_DECIMALS = IERC20Metadata(_paymentToken).decimals();
        auctionToken.safeTransferFrom(msg.sender, address(this), _totalTokens);
    }

    /// @notice Modify auction params
    function modifyAuctionParams(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _startPrice,
        uint256 _minPrice
    )
        external
        onlyOwner
    {
        require(_startTime >= block.timestamp, "DutchAuction: start time is before current time");
        require(_endTime > _startTime, "DutchAuction: end time must be older than start time");
        require(_startPrice > _minPrice, "DutchAuction: start price must be > min price");
        require(_minPrice > 0, "DutchAuction: min price must be > 0");
        require(
            marketStatus.commitmentsTotal == 0, "DutchAuction: auction cannot have already started"
        );

        marketInfo.startTime = _startTime;
        marketInfo.endTime = _endTime;
        marketPrice.startPrice = _startPrice;
        marketPrice.minPrice = _minPrice;

        emit ModifiedAuctionParams(
            msg.sender,
            address(auctionToken),
            address(paymentToken),
            _startTime,
            _endTime,
            _startPrice,
            _minPrice
            );
    }

    /// @notice Calculates avg token price based on comittments
    /// @dev Adjusts decimals as needed
    function tokenPrice() public view returns (uint256) {
        if (PAYMENT_TOKEN_DECIMALS < 18) {
            return (marketStatus.commitmentsTotal * 1e18 * 10 ** (18 - PAYMENT_TOKEN_DECIMALS))
                / marketInfo.totalTokens;
        } else {
            return (marketStatus.commitmentsTotal * 1e18) / marketInfo.totalTokens;
        }
    }

    /// @notice Gets token price during auction
    /// @dev Adjusts decimals as needed
    function priceFunction() public view returns (uint256) {
        if (block.timestamp <= marketInfo.startTime) {
            return marketPrice.startPrice;
        }
        if (block.timestamp >= marketInfo.endTime) {
            return marketPrice.minPrice;
        }

        if (PAYMENT_TOKEN_DECIMALS < 18) {
            return _currentPrice() / (10 ** (18 - PAYMENT_TOKEN_DECIMALS));
        } else {
            return _currentPrice();
        }
    }

    /// @notice Gets clearing price (max of tokenPrice and priceFunction())
    function clearingPrice() public view returns (uint256) {
        uint256 _tokenPrice = tokenPrice();
        uint256 _currPrice = priceFunction();
        return _tokenPrice > _currPrice ? _tokenPrice : _currPrice;
    }

    /// @notice Commit amount of paymentToken
    function commitTokens(uint256 _amount) external nonReentrant {
        uint256 tokensToTransfer = calculateCommitment(_amount);

        if (tokensToTransfer > 0) {
            paymentToken.safeTransferFrom(msg.sender, address(this), tokensToTransfer);
            _addCommitment(msg.sender, tokensToTransfer);
        }
    }

    /// @notice Calculates tokens a user can claim
    function tokensClaimable(address _user) public view returns (uint256 claimerCommitment) {
        if (commitments[_user] == 0) {
            return 0;
        }
        uint256 unclaimedTokens = IERC20(auctionToken).balanceOf(address(this));

        claimerCommitment =
            (commitments[_user] * (marketInfo.totalTokens)) / (marketStatus.commitmentsTotal);
        claimerCommitment = claimerCommitment - claimed[_user];

        if (claimerCommitment > unclaimedTokens) {
            claimerCommitment = unclaimedTokens;
        }
    }

    /// @notice Calculates comittment amount during auction
    /// @dev Represents the "share" amount of total token allocation
    function calculateCommitment(uint256 _commitment) public view returns (uint256 committed) {
        uint256 maxCommitment = (marketInfo.totalTokens * (clearingPrice())) / 1e18;
        if (marketStatus.commitmentsTotal + _commitment > maxCommitment) {
            return maxCommitment - marketStatus.commitmentsTotal;
        }
        return _commitment;
    }

    /// @notice Successful if tokens sold equals totalTokens
    function auctionSuccessful() public view returns (bool) {
        return tokenPrice() >= clearingPrice();
    }

    /// @notice Checks if auction ended
    function auctionEnded() external view returns (bool) {
        return auctionSuccessful() || block.timestamp >= marketInfo.endTime;
    }

    /// @notice Calculates price during auction
    function _currentPrice() private view returns (uint256) {
        MarketInfo memory _marketInfo = marketInfo;
        MarketPrice memory _marketPrice = marketPrice;

        // The priceDelta/timeDelta = linear change in price
        uint256 priceDelta = _marketPrice.startPrice - _marketPrice.minPrice;
        uint256 timeDelta = _marketInfo.endTime - _marketInfo.startTime;

        // Calculates current timestamp * priceDelta/timeDelta
        uint256 priceChange = ((block.timestamp - _marketInfo.startTime) * priceDelta) / timeDelta;

        return _marketPrice.startPrice - priceChange;
    }

    /// @notice Adds commitment
    function _addCommitment(address _addr, uint256 _commitment) internal {
        require(
            block.timestamp >= marketInfo.startTime && block.timestamp <= marketInfo.endTime,
            "DutchAuction: outside auction hours"
        );
        MarketStatus storage status = marketStatus;

        uint256 newCommitment = commitments[_addr] + _commitment;
        commitments[_addr] = newCommitment;
        status.commitmentsTotal = status.commitmentsTotal + _commitment;
        emit AddedCommitment(
            msg.sender,
            address(auctionToken),
            address(paymentToken),
            _commitment,
            PAYMENT_TOKEN_DECIMALS
            );
    }

    /// @notice Cancel auction
    function cancelAuction() external nonReentrant onlyOwner {
        MarketStatus storage status = marketStatus;
        require(!status.finalized, "DutchAuction: auction already finalized");
        require(status.commitmentsTotal == 0, "DutchAuction: auction already committed");
        auctionToken.safeTransferFrom(address(this), msg.sender, marketInfo.totalTokens);
        status.finalized = true;
    }

    /// @notice Finalize auction by transferring contract funds to owner
    function finalize() external nonReentrant onlyOwner {
        require(marketInfo.totalTokens > 0, "DutchAuction: auction not initialized");

        MarketStatus storage status = marketStatus;
        require(!status.finalized, "DutchAuction: auction already finalized");

        if (auctionSuccessful()) {
            // Successful auction - transfer payment tokens
            paymentToken.safeTransfer(msg.sender, status.commitmentsTotal);
        } else {
            // Unsuccessful auction - return auction tokens
            require(
                block.timestamp > marketInfo.endTime, "DutchAuction: auction has not finished yet"
            );
            auctionToken.safeTransfer(msg.sender, marketInfo.totalTokens);
        }
        status.finalized = true;
    }

    /// @notice Withdraws tokens purchased or returns commitment is sale was not met
    function withdrawTokens() external nonReentrant {
        if (auctionSuccessful()) {
            require(marketStatus.finalized, "DutchAuction: not finalized");
            uint256 tokensToClaim = tokensClaimable(msg.sender);
            require(tokensToClaim > 0, "DutchAuction: No tokens to claim");
            claimed[msg.sender] = claimed[msg.sender] + (tokensToClaim);
            auctionToken.safeTransfer(msg.sender, tokensToClaim);
        } else {
            // Returns funds back to user if auction was unsuccessful
            require(
                block.timestamp > marketInfo.endTime, "DutchAuction: auction has not finished yet"
            );
            uint256 fundsCommitted = commitments[msg.sender];
            commitments[msg.sender] = 0;
            paymentToken.safeTransfer(msg.sender, fundsCommitted);
        }
    }
}
