// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

interface ICurveFactory {
    function deploy_metapool(
        address _base_pool,
        string memory _name,
        string memory _symbol,
        address _coin,
        uint256 _A,
        uint256 _fee,
        uint256 _implementation_idx
    )
        external
        returns (address);

    function get_underlying_coins(address _pool) external view returns (address[8] memory);
    function get_meta_n_coins(address _pool) external view returns (uint256);
    function get_coin_indices(address _pool, address _from, address _to)
        external
        view
        returns (int128 outboundIndex, int128 phoIndex, bool isUnderlying);
    function get_coins(address _pool) external view returns (address[2] memory);
    function get_underlying_balances(address _pool) external view returns (uint256[8] memory);
    function get_base_pool(address _pool) external view returns (address);
    function is_meta(address _pool) external view returns(bool);
}

