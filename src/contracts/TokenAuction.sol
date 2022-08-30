// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {PRBMathSD59x18} from "@prb-math/contracts/PRBMathSD59x18.sol";

/// @notice Basic Token Auction with Continuous GDA
contract TokenAuction is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using PRBMathSD59x18 for int256; // 59x18 fixed precision numbers

    // State vars
    int256 internal immutable initialPrice;
    int256 internal immutable decayConstant;
    int256 internal immutable emissionRate; // tokens per second
    int256 internal lastAvailableAuctionStartTime;
    IERC20 public immutable principalToken; // principal - example: USDC, DAI
    IERC20 public immutable payoutToken; // payout - example: TON
    uint8 private immutable PRINCIPAL_TOKEN_DECIMALS;
    uint8 private constant PAYOUT_TOKEN_DECIMALS = 18;
    mapping(address => bool) public whitelist;
    mapping(address => uint256) public purchasedAmounts;
    uint256 public maxPerBuyer = 5000;

    // Errors
    error InsufficientPayment();
    error InsufficientAvailableTokens();

    // Events
    event AddedToWhiteList(address indexed addr);
    event RemovedFromWhiteList(address indexed addr);
    event MaxPerBuyerModified(uint256 maxPerBuyer);
    event PurchasedTokens(address indexed buyer, uint256 numTokens, uint256 depositAmount);

    /// Constructor
    constructor(
        address _principalToken,
        address _payoutToken,
        int256 _initialPrice,
        int256 _decayConstant,
        int256 _emissionRate
    ) {
        require(_payoutToken != address(0), "payout token = 0");
        require(_principalToken != address(0), "principal token = 0");

        principalToken = IERC20(_principalToken);
        payoutToken = IERC20(_payoutToken);
        initialPrice = _initialPrice;
        decayConstant = _decayConstant;
        emissionRate = _emissionRate;

        PRINCIPAL_TOKEN_DECIMALS = IERC20Metadata(_principalToken).decimals();
        lastAvailableAuctionStartTime = int256(block.timestamp).fromInt();
    }

    /// @notice Add to whitelist
    function addToWhiteList(address _addr) external onlyOwner {
        whitelist[_addr] = true;
        emit AddedToWhiteList(_addr);
    }

    /// @notice Remove from whitelist
    function removeFromWhiteList(address _addr) external onlyOwner {
        delete whitelist[_addr];
        emit RemovedFromWhiteList(_addr);
    }

    /// @notice Modify max per buyer
    function modifyMaxPerBuyer(uint256 _maxPerBuyer) external onlyOwner {
        maxPerBuyer = _maxPerBuyer;
        emit MaxPerBuyerModified(_maxPerBuyer);
    }

    /// @notice Purchase a specific number of payout tokens
    function purchaseTokens(uint256 numTokens, uint256 depositAmount) external nonReentrant {
        require(purchasedAmounts[msg.sender] + numTokens < maxPerBuyer, "MaxPerBuyer exceeded");
        require(whitelist[msg.sender], "Must be whitelisted");

        // number of seconds of token emissions that are available to be purchased
        int256 secondsOfEmissionsAvaiable =
            int256(block.timestamp).fromInt() - lastAvailableAuctionStartTime;
        // number of seconds of emissions are being purchased
        int256 secondsOfEmissionsToPurchase = int256(numTokens).fromInt().div(emissionRate);
        // ensure there's been sufficient emissions to allow purchase
        if (secondsOfEmissionsToPurchase > secondsOfEmissionsAvaiable) {
            revert InsufficientAvailableTokens();
        }

        // get cost and normalize as needed
        uint256 cost = purchasePrice(numTokens); // cost in payoutToken terms
        uint256 principalPayment = cost / (10 ** (PAYOUT_TOKEN_DECIMALS - PRINCIPAL_TOKEN_DECIMALS)); // scale decimals as needed
        if (depositAmount < principalPayment) {
            revert InsufficientPayment();
        }

        purchasedAmounts[msg.sender] += numTokens;

        // user sends principal tokens
        principalToken.safeTransferFrom(msg.sender, address(this), depositAmount);

        // user recieves payout tokens
        payoutToken.safeTransferFrom(address(this), msg.sender, numTokens);

        // update last available auction
        lastAvailableAuctionStartTime += secondsOfEmissionsToPurchase;

        emit PurchasedTokens(msg.sender, numTokens, depositAmount);
    }

    ///@notice Calculate purchase price (in payoutToken terms) using exponential CGDA formula
    function purchasePrice(uint256 numTokens) public view returns (uint256) {
        int256 quantity = int256(numTokens).fromInt();
        int256 timeSinceLastAuctionStart =
            int256(block.timestamp).fromInt() - lastAvailableAuctionStartTime;
        int256 num1 = initialPrice.div(decayConstant);
        int256 num2 =
            decayConstant.mul(quantity).div(emissionRate).exp() - PRBMathSD59x18.fromInt(1);
        int256 den = decayConstant.mul(timeSinceLastAuctionStart).exp();
        int256 totalCost = num1.mul(num2).div(den);
        return uint256(totalCost);
    }
}
