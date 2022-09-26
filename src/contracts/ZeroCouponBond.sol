// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IPHO.sol";

/// @title ZeroCouponBond
/// @author Ekonomia: https://github.com/ekonomia-tech
/// @notice Example of simple fixed-expiry zero-coupon bond
contract ZeroCouponBond is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    /// State vars
    address public controller;
    IPHO public pho; // depositors recieve pho
    address public depositToken; // assuming stablecoin deposits
    uint256 public interestRate; // 10 ** 6 scale
    uint256 public constant INTEREST_RATE_PRECISION = 1e6;
    uint256 public depositWindowEnd; // latest time to deposit
    uint256 public maturityTimestamp;
    uint8 depositTokenDecimals;
    mapping(address => uint256) public issuedAmount;

    /// Events
    event BondIssued(address indexed depositor, uint256 depositAmount, uint256 mintAmount);
    event BondRedeemed(address indexed redeemer, uint256 redeemAmount);
    event InterestRateSet(uint256 interestRate);

    modifier onlyByOwnerOrController() {
        require(
            msg.sender == owner() || msg.sender == controller,
            "ZeroCouponBond: not owner or controller"
        );
        _;
    }

    /// Constructor
    constructor(
        address _controller,
        address _pho,
        address _depositToken,
        string memory _bondTokenName,
        string memory _bondTokenSymbol,
        uint256 _interestRate,
        uint256 _depositWindowEnd,
        uint256 _maturityTimestamp
    )
        ERC20(_bondTokenName, _bondTokenSymbol)
    {
        require(
            _controller != address(0) && _pho != address(0) && _depositToken != address(0),
            "ZeroCouponBond: zero address detected"
        );
        require(
            _maturityTimestamp > block.timestamp && _depositWindowEnd > block.timestamp,
            "ZeroCouponBond: timestamps must be in future"
        );
        depositToken = _depositToken;
        depositTokenDecimals = IERC20Metadata(_depositToken).decimals();
        require(depositTokenDecimals <= 18, "ZeroCouponBond: depositToken must be < 18 decimals");
        pho = IPHO(_pho);
        controller = _controller;
        interestRate = _interestRate;
        depositWindowEnd = _depositWindowEnd;
        maturityTimestamp = _maturityTimestamp;
    }

    /// @notice user deposits for bond
    /// @param depositAmount deposit amount (in depositToken decimals)
    function depositBond(uint256 depositAmount) external nonReentrant {
        require(
            block.timestamp <= depositWindowEnd, "ZeroCouponBond: cannot deposit after window end"
        );
        // scale if decimals < 18
        uint256 scaledDepositAmount = depositAmount;
        scaledDepositAmount = depositAmount * (10 ** (18 - depositTokenDecimals));

        // Transfer depositToken
        ERC20(depositToken).safeTransferFrom(msg.sender, address(this), depositAmount);

        // Mint ZCB to caller
        uint256 mintAmount = (scaledDepositAmount * (INTEREST_RATE_PRECISION + interestRate))
            / INTEREST_RATE_PRECISION;
        issuedAmount[msg.sender] += mintAmount;
        _mint(msg.sender, mintAmount);

        emit BondIssued(msg.sender, depositAmount, mintAmount);
    }

    /// @notice user redeems their bond
    /// @param redeemAmount redeem amount - 18 decimals
    function redeemBond(uint256 redeemAmount) external nonReentrant {
        require(
            block.timestamp >= maturityTimestamp, "ZeroCouponBond: maturityTimestamp not reached"
        );
        require(redeemAmount <= issuedAmount[msg.sender], "ZeroCouponBond: cannot redeem > issued");

        issuedAmount[msg.sender] -= redeemAmount;

        // burn ZCB from caller
        _burn(msg.sender, redeemAmount);

        // transfer PHO to caller
        pho.transfer(msg.sender, redeemAmount);

        emit BondRedeemed(msg.sender, redeemAmount);
    }

    /// @notice set interest rate
    /// @param _interestRate interest rate to set
    function setInterestRate(uint256 _interestRate) external onlyByOwnerOrController {
        require(_interestRate > 0, "ZeroCouponBond: interest rate must be > 0");
        interestRate = _interestRate;
        emit InterestRateSet(_interestRate);
    }
}
