// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

/// @notice interface to be able to access metapool factory. Not sure if needed though in full.
interface ICurveFactory {
    function deploy_metapool(
        address _base_pool,
        string[32] calldata _name,
        string[10] calldata _symbol,
        address _coin,
        uint256 _A,
        uint256 _fee,
        uint256 _implementation_idx
    )
        external
        view
        returns (address);
}
