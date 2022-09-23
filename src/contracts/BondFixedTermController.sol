// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import {BondBaseController} from "./BondBaseController.sol";
import {IBondDispatcher} from "../interfaces/IBondDispatcher.sol";

/// @title Bond Fixed Term Controller
/// @author Ekonomia: https://github.com/ekonomia-tech
/// @dev An implementation of the BondBaseController for bond markets withfixed term
contract BondFixedTermController is BondBaseController {
    /// Constructor
    constructor(
        IBondDispatcher _bondDispatcher,
        address _controllerAddress,
        address _phoAddress,
        address _tonAddress
    )
        BondBaseController(
            _bondDispatcher,
            _controllerAddress,
            _phoAddress,
            _tonAddress
        )
    {}

    /// @inheritdoc BondBaseController
    function createMarket(bytes calldata params_)
        external
        override
        returns (uint256)
    {
        MarketParams memory params = abi.decode(params_, (MarketParams));
        return _createMarket(params);
    }
}
