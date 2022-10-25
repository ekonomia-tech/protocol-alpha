// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@protocol/interfaces/IPHO.sol";
import "@protocol/interfaces/IModuleManager.sol";

/// @title ZeroCouponBondModule
/// @author Ekonomia: https://github.com/ekonomia-tech
/// @notice Example of simple fixed-expiry zero-coupon bond
contract ZeroCouponBondModule is ERC20, Ownable, ReentrancyGuard {
    /// Errors
    error ZeroAddressDetected();
    error DepositWindowInvalid();
    error DepositTokenTooManyDecimals();
    error CannotDepositAfterWindowEnd();
    error MaturityNotReached();
    error CannotRedeemMoreThanIssued();

    /// State vars
    IModuleManager public moduleManager;
    address public kernel;
    IPHO public pho; // depositors recieve PHO
    IERC20Metadata public depositToken; // assuming stablecoin deposits
    uint256 public interestRate; // 10 ** 6 scale
    uint256 public constant INTEREST_RATE_PRECISION = 1e6;
    uint256 public depositWindowOpen; // earliest time to deposit
    uint256 public depositWindowEnd; // latest time to deposit - maturity
    uint256 public duration;
    uint8 public depositTokenDecimals;
    mapping(address => uint256) public issuedAmount;

    /// Events
    event BondIssued(address indexed depositor, uint256 depositAmount, uint256 mintAmount);
    event BondRedeemed(address indexed redeemer, uint256 redeemAmount);
    event InterestRateSet(uint256 interestRate);

    modifier onlyModuleManager() {
        require(msg.sender == address(moduleManager), "Only ModuleManager");
        _;
    }

    /// Constructor
    constructor(
        address _moduleManager,
        address _kernel,
        address _pho,
        address _depositToken,
        string memory _bondTokenName,
        string memory _bondTokenSymbol,
        uint256 _interestRate,
        uint256 _depositWindowOpen,
        uint256 _depositWindowEnd
    ) ERC20(_bondTokenName, _bondTokenSymbol) {
        if (
            _moduleManager == address(0) || _kernel == address(0) || _pho == address(0)
                || _depositToken == address(0)
        ) {
            revert ZeroAddressDetected();
        }
        if (_depositWindowEnd <= block.timestamp || _depositWindowOpen >= _depositWindowEnd) {
            revert DepositWindowInvalid();
        }
        depositToken = IERC20Metadata(_depositToken);
        depositTokenDecimals = depositToken.decimals();
        if (depositTokenDecimals > 18) {
            revert DepositTokenTooManyDecimals();
        }
        pho = IPHO(_pho);
        moduleManager = IModuleManager(_moduleManager);
        interestRate = _interestRate;
        depositWindowOpen = _depositWindowOpen;
        depositWindowEnd = _depositWindowEnd;
        duration = _depositWindowEnd - _depositWindowOpen;
    }

    /// @notice user deposits for bond
    /// @param depositAmount deposit amount (in depositToken decimals)
    function depositBond(uint256 depositAmount) external nonReentrant {
        if (block.timestamp > depositWindowEnd) {
            revert CannotDepositAfterWindowEnd();
        }
        // scale if decimals < 18
        uint256 scaledDepositAmount = depositAmount;
        scaledDepositAmount = depositAmount * (10 ** (18 - depositTokenDecimals));

        // transfer depositToken
        depositToken.transferFrom(msg.sender, address(this), depositAmount);

        // mint ZCB to caller - adjusted interest rate
        uint256 adjustedInterestRate = block.timestamp > depositWindowOpen
            ? ((interestRate * (block.timestamp - depositWindowOpen)) / duration)
            : interestRate;
        uint256 mintAmount = (
            scaledDepositAmount * (INTEREST_RATE_PRECISION + adjustedInterestRate)
        ) / INTEREST_RATE_PRECISION;
        issuedAmount[msg.sender] += mintAmount;
        _mint(msg.sender, mintAmount);

        emit BondIssued(msg.sender, depositAmount, mintAmount);
    }

    /// @notice user redeems their bond
    /// @param redeemAmount redeem amount - 18 decimals
    function redeemBond(uint256 redeemAmount) external nonReentrant {
        if (block.timestamp < depositWindowEnd) {
            revert MaturityNotReached();
        }
        if (redeemAmount > issuedAmount[msg.sender]) {
            revert CannotRedeemMoreThanIssued();
        }

        issuedAmount[msg.sender] -= redeemAmount;

        // burn ZCB from caller
        _burn(msg.sender, redeemAmount);

        // transfer PHO to caller
        moduleManager.mintPHO(msg.sender, redeemAmount);

        emit BondRedeemed(msg.sender, redeemAmount);
    }

    /// @notice set interest rate
    /// @param _interestRate interest rate to set
    function setInterestRate(uint256 _interestRate) external onlyModuleManager {
        interestRate = _interestRate;
        emit InterestRateSet(_interestRate);
    }
}
