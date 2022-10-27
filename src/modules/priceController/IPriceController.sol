// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

interface IPriceController {
    error ZeroAddress();
    error SameAddress();
    error ZeroValue();
    error SameValue();
    error CooldownPeriodAtLeastOneHour();
    error ValueNotInRange();
    error CooldownNotSatisfied();
    error NotEnoughBalanceInStabilizer();

    event OracleAddressSet(address indexed newOracleAddress);
    event CooldownPeriodUpdated(uint256 newCooldownPeriod);
    event PriceMitigationPercentageUpdated(uint256 newGapFraction);
    event TokensExchanged(
        address indexed dexPool,
        address indexed tokenSent,
        uint256 amountSent,
        address tokenReceived,
        uint256 amountReceived
    );
    event MaxSlippageUpdated(uint256 newMaxSlippage);

    function stabilize() external returns (bool);
    function setOracleAddress(address newOracleAddress) external;
    function setCooldownPeriod(uint256 newCooldownPeriod) external;
    function setPriceMitigationPercentage(uint256 newGapFraction) external;
    function setMaxSlippage(uint256 newMaxSlippage) external;
}
