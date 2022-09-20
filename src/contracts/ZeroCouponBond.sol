// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./PHO.sol";

/// @title ZeroCouponBond
/// @author Ekonomia: https://github.com/ekonomia-tech
/// @notice Examplee of simple fixed-term zero-coupon bond
contract ZeroCouponBond is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    /// State vars
    address public controller;
    PHO public pho; // depositors recieve pho
    ERC20 public depositToken; // assuming astablecoin deposits
    uint256 public interestRate; // 1e6 scale
    uint256 public constant INTEREST_RATE_PRECISION = 1e6;
    uint256 public maturityTimestamp;
    uint8 depositTokenDecimals;
    mapping(address => uint256) public issuedAmount;

    /// Events
    event BondIssued(address indexed depositor, uint256 depositAmount);
    event BondRedeemed(address indexed redeemer, uint256 redeemAmount);

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
        uint256 _maturityTimestamp
    )
        ERC20(_bondTokenName, _bondTokenSymbol)
    {
        require(_controller != address(0), "ZeroCouponBond: zero address detected");
        require(_pho != address(0), "ZeroCouponBond: zero address detected");
        require(_depositToken != address(0), "ZeroCouponBond: zero address detected");
        require(
            _maturityTimestamp > block.timestamp,
            "ZeroCouponBond: maturityTimestamp must be in future"
        );
        depositToken = ERC20(_depositToken);
        depositTokenDecimals = IERC20Metadata(_depositToken).decimals();
        pho = PHO(_pho);
        controller = _controller;
        interestRate = _interestRate;
        maturityTimestamp = _maturityTimestamp;
    }

    /// @notice user deposits for bond
    /// @param depositAmount deposit amount (in depositToken decimals)
    function depositBond(uint256 depositAmount) external nonReentrant {
        // scale if decimals < 18
        uint256 scaledDepositAmount = depositAmount;
        if (depositTokenDecimals != 18) {
            scaledDepositAmount = depositAmount * (10 ** (18 - depositTokenDecimals));
        }

        // Transfer depositToken
        depositToken.safeTransferFrom(msg.sender, address(this), depositAmount);

        // Mint ZCB to caller
        uint256 mintAmount = (scaledDepositAmount * (INTEREST_RATE_PRECISION + interestRate))
            / INTEREST_RATE_PRECISION;
        issuedAmount[msg.sender] += mintAmount;
        _mint(msg.sender, mintAmount);

        emit BondIssued(msg.sender, depositAmount);
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
        interestRate = _interestRate;
    }
}
