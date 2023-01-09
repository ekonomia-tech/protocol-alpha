// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IZeroCouponBondModule {
    /// Errors
    error ZeroAddressDetected();
    error DepositWindowInvalid();
    error OverEighteenDecimals();
    error CannotDepositBeforeWindowOpen();
    error CannotDepositAfterWindowEnd();
    error CannotRedeemBeforeWindowEnd();
    error CannotRedeemMoreThanIssued();
    error OnlyModuleManager();

    /// Events
    event BondIssued(address indexed depositor, uint256 depositAmount, uint256 mintAmount);
    event FTBondRedeemed(address indexed redeemer, uint256 redeemAmount);
    event InterestRateSet(uint256 interestRate);

    function depositBond(uint256 depositAmount) external;

    function redeemBond() external;

    function setInterestRate(uint256 interestRate) external;
}
