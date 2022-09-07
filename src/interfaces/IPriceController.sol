// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

interface IPriceController {
    event ControllerSet(address controller_address);
    event OracleAddressSet(address oracle_address);
    event CooldownPeriodUpdated(uint256 previousCooldownPeriod, uint256 newCooldownPeriod);
    event PriceBandUpdated(uint256 previousPriceBand, uint256 newPriceBand);
    event GapFractionUpdated(uint256 previousGapFraction, uint256 newGapFraction);
    event TokensExchanged(
        address dexPool,
        address tokenSent,
        uint256 amountSent,
        address tokenReceived,
        uint256 amountReceived
    );
    event DexPoolUpdated(address newDexPool);
    event StabilizingTokenUpdated(address stabilizingToken);
    event MaxSlippageUpdated(uint256 perviousMaxSlippage, uint256 newMaxSlippage);

    function setController(address _controller_address) external;
    function setOracleAddress(address _oracle_address) external;
    function setCooldownPeriod(uint256 _cooldown_period) external;
    function setPriceBand(uint256 _price_band) external;
    function setGapFraction(uint256 _gap_fraction) external;
    function setDexPool(address _dex_pool_address) external;
    function setStabilizingToken(address _stabilizing_token) external;
    function setMaxSlippage(uint256 _max_slippage) external;
}
