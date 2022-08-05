// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

interface IShare {
    function setOracle(address new_oracle) external;
    function setTimelock(address new_timelock) external;
    function setEUSDAddress(address frax_contract_address) external;
    function mint(address to, uint256 amount) external;
    function pool_mint(address m_address, uint256 m_amount) external;
    function pool_burn_from(address b_address, uint256 b_amount) external;
}