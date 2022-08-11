// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./Setup.t.sol";

error Unauthorized();

contract PIDControllerTest is Setup {    

    /// EVENTS

    /// IPIDController events

    event CollateralRatioRefreshed(uint256 global_collateral_ratio);
    event RedemptionFeeSet(uint256 red_fee);
    event MintingFeeSet(uint256 min_fee);
    event EUSDStepSet(uint256 new_step);
    event PriceTargetSet(uint256 new_price_target);
    event RefreshCooldownSet(uint256 new_cooldown);
    event SHAREAddressSet(address _SHARE_address);
    event ETHUSDOracleSet(address eth_usd_consumer_address);
    event TimelockSet(address new_timelock);
    event ControllerSet(address controller_address);
    event PriceBandSet(uint256 price_band);
    event EUSDETHOracleSet(address EUSD_oracle_addr, address weth_address);
    event SHAREEthOracleSet(address SHARE_oracle_addr, address weth_address);
    event CollateralRatioToggled(bool collateral_ratio_paused);

    /// IAccessControl events

    event RoleAdminChanged(
        bytes32 indexed role,
        bytes32 indexed previousAdminRole,
        bytes32 indexed newAdminRole
    );
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /// Ownable events
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    /// setup tests
}