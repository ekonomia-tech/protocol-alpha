// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@protocol/interfaces/IPHO.sol";
import "@protocol/interfaces/IModuleManager.sol";
import "./IZeroCouponBondModule.sol";

/// @title ZeroCouponBondModule
/// @author Ekonomia: https://github.com/ekonomia-tech
/// @notice Example of simple fixed-expiry zero-coupon bond
contract ZeroCouponBondModule is ERC20, IZeroCouponBondModule, Ownable, ReentrancyGuard {
    /// State vars
    IModuleManager public moduleManager;
    address public kernel;
    IPHO public pho; // depositors receive PHO
    IERC20Metadata public depositToken; // assuming stablecoin deposits
    uint256 public interestRate; // 10 ** 6 scale
    uint256 public constant INTEREST_RATE_PRECISION = 1e6;
    uint256 public depositWindowOpen; // earliest time to deposit
    uint256 public depositWindowEnd; // acts as latest time to deposit as well as bond maturity time
    uint256 public duration;
    uint8 public depositTokenDecimals;
    mapping(address => uint256) public issuedAmount;

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
        if (_depositWindowEnd <= _depositWindowOpen || _depositWindowOpen <= block.timestamp) {
            revert DepositWindowInvalid();
        }
        depositToken = IERC20Metadata(_depositToken);
        depositTokenDecimals = depositToken.decimals();
        if (depositTokenDecimals > 18) {
            revert OverEighteenDecimals();
        }
        pho = IPHO(_pho);
        moduleManager = IModuleManager(_moduleManager);
        interestRate = _interestRate;
        depositWindowOpen = _depositWindowOpen;
        depositWindowEnd = _depositWindowEnd;
        duration = _depositWindowEnd - _depositWindowOpen;
    }

    /// @notice User deposits for bond
    /// @param depositAmount Deposit amount (in depositToken decimals)
    function depositBond(uint256 depositAmount) external override nonReentrant {
        if (block.timestamp < depositWindowOpen) {
            revert CannotDepositBeforeWindowOpen();
        }
        if (block.timestamp > depositWindowEnd) {
            revert CannotDepositAfterWindowEnd();
        }

        // scale if decimals < 18
        uint256 scaledDepositAmount = depositAmount * (10 ** (18 - depositTokenDecimals));

        // transfer depositToken
        depositToken.transferFrom(msg.sender, address(this), depositAmount);

        // mint ZCB to caller - adjusted interest rate
        uint256 adjustedInterestRate = block.timestamp == depositWindowOpen
            ? interestRate
            : ((interestRate * (block.timestamp - depositWindowOpen)) / duration);
        uint256 mintAmount = (
            scaledDepositAmount * (INTEREST_RATE_PRECISION + adjustedInterestRate)
        ) / INTEREST_RATE_PRECISION;
        issuedAmount[msg.sender] += mintAmount;
        _mint(msg.sender, mintAmount);

        emit BondIssued(msg.sender, depositAmount, mintAmount);
    }

    /// @notice User redeems their bond (full amount)
    function redeemBond() external override nonReentrant {
        if (block.timestamp < depositWindowEnd) {
            revert CannotRedeemBeforeWindowEnd();
        }

        uint256 redeemAmount = issuedAmount[msg.sender];

        issuedAmount[msg.sender] -= redeemAmount;

        // burn ZCB from caller
        _burn(msg.sender, redeemAmount);

        // transfer PHO to caller
        moduleManager.mintPHO(msg.sender, redeemAmount);

        emit FTBondRedeemed(msg.sender, redeemAmount);
    }

    /// @notice Set interest rate
    /// @param _interestRate Interest rate to set
    function setInterestRate(uint256 _interestRate) external {
        if (msg.sender != address(moduleManager)) {
            revert OnlyModuleManager();
        }
        interestRate = _interestRate;
        emit InterestRateSet(_interestRate);
    }
}
