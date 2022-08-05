// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

interface IPIDController {

    event CollateralRatioRefreshed(uint256 global_collateral_ratio);
    event RedemptionFeeSet(uint256 red_fee);
    event MintingFeeSet(uint256 min_fee);
    event FraxStepSet(uint256 new_step);
    event PriceTargetSet(uint256 new_price_target);
    event RefreshCooldownSet(uint256 new_cooldown);
    event FXSAddressSet(address _fxs_address);
    event ETHUSDOracleSet(address eth_usd_consumer_address);
    event TimelockSet(address new_timelock);
    event ControllerSet(address controller_address);
    event PriceBandSet(uint256 price_band);
    event FRAXETHOracleSet(address frax_oracle_addr, address weth_address);
    event FXSEthOracleSet(address fxs_oracle_addr, address weth_address);
    event CollateralRatioToggled(bool collateral_ratio_paused);

    function frax_price() external view returns (uint256);
    function fxs_price()  external view returns (uint256);
    function eth_usd_price() external view returns (uint256);
    function frax_info() external view returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256);
    function globalCollateralValue() external view returns (uint256);
    function refreshCollateralRatio() external;
    function setRedemptionFee(uint256 red_fee) external;
    function setMintingFee(uint256 min_fee) external;
    function setFraxStep(uint256 _new_step) external;
    function setPriceTarget (uint256 _new_price_target) external;
    function setRefreshCooldown(uint256 _new_cooldown) external;
    function setFXSAddress(address _fxs_address) external; 
    function setETHUSDOracle(address _eth_usd_consumer_address) external  ;
    function setTimelock(address new_timelock) external  ;
    function setController(address _controller_address) external  ;
    function setPriceBand(uint256 _price_band) external  ;
    function setFRAXEthOracle(address _frax_oracle_addr, address _weth_address) external  ;
    function setFXSEthOracle(address _fxs_oracle_addr, address _weth_address) external  ;
    function toggleCollateralRatio() external;
}