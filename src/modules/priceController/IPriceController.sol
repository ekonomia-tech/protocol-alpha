// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

interface IPriceController {
    error NotSelf();
    error ZeroAddress();
    error SameAddress();
    error ZeroValue();
    error SameValue();
    error CooldownPeriodAtLeastOneHour();
    error ValueNotInRange();
    error CooldownNotSatisfied();
    error NotEnoughBalanceInStabilizer();
    error TokenNotUnderlyingInMetapool();
    error AddressDoNotPointToMetapool();
    error PHONotPresentInMetapool();

    event OracleAddressSet(address indexed newOracleAddress);
    event CooldownPeriodUpdated(uint256 newCooldownPeriod);
    event PriceBandUpdated(uint256 newPriceBand);
    event GapFractionUpdated(uint256 newGapFraction);
    event TokensExchanged(
        address indexed dexPool,
        address indexed tokenSent,
        uint256 amountSent,
        address tokenReceived,
        uint256 amountReceived
    );
    event DexPoolUpdated(address indexed newDexPool);
    event StabilizingTokenUpdated(address indexed newStabilizingToken);
    event MaxSlippageUpdated(uint256 newMaxSlippage);

    function setOracleAddress(address newOracleAddress) external;
    function setCooldownPeriod(uint256 newCooldownPeriod) external;
    function setPriceBand(uint256 newPriceBand) external;
    function setGapFraction(uint256 newGapFraction) external;
    function setDexPool(address newDexPool) external;
    function setStabilizingToken(address newStabilizingToken) external;
    function setMaxSlippage(uint256 newMaxSlippage) external;
}
