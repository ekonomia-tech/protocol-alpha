// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

interface IPriceController {
    event ControllerSet(address newConrollerAddress);
    event OracleAddressSet(address newOracleAddress);
    event CooldownPeriodUpdated(uint256 newCooldownPeriod);
    event PriceBandUpdated(uint256 newPriceBand);
    event GapFractionUpdated(uint256 newGapFraction);
    event TokensExchanged(
        address dexPool,
        address tokenSent,
        uint256 amountSent,
        address tokenReceived,
        uint256 amountReceived
    );
    event DexPoolUpdated(address newDexPool);
    event StabilizingTokenUpdated(address newStabilizingToken);
    event MaxSlippageUpdated(uint256 newMaxSlippage);

    function setController(address newControllerAddress) external;
    function setOracleAddress(address newOracleAddress) external;
    function setCooldownPeriod(uint256 newCooldownPeriod) external;
    function setPriceBand(uint256 newPriceBand) external;
    function setGapFraction(uint256 newGapFraction) external;
    function setDexPool(address newDexPool) external;
    function setStabilizingToken(address newStabilizingToken) external;
    function setMaxSlippage(uint256 newMaxSlippage) external;
}
