// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

interface IEUSD {

    /// Track EUSD burned 
    event EUSDBurned(address indexed from, address indexed burnCaller, uint256 amount);
    /// Track EUSD minted
    event EUSDMinted(address indexed mintCaller, address indexed to, uint256 amount);
    /// Track pools added
    event PoolAdded(address pool_address);
    /// Track pools removed
    event PoolRemoved(address pool_address);
    /// Track governing controller contract
    event ControllerSet(address controller_address);

    function pool_burn_from(address b_address, uint256 b_amount) external;
    function pool_mint(address m_address, uint256 m_amount) external;
    function addPool(address pool_address) external;
    function removePool(address pool_address) external;
    function setController(address _controller_address) external;
    function burn(uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;

}