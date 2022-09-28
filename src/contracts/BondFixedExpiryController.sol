// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import {BondBaseController} from "./BondBaseController.sol";
import {IBondDispatcher} from "../interfaces/IBondDispatcher.sol";
import {IBondFixedExpiryDispatcher} from "../interfaces/IBondFixedExpiryDispatcher.sol";

/// @title Bond Fixed Expiry Controller
/// @author Ekonomia: https://github.com/ekonomia-tech
/// @dev An implementation of the BondBaseController for bond markets that vest with a fixed expiry
contract BondFixedExpiryController is BondBaseController {
    /// Constructor
    constructor(
        address _bondDispatcher,
        address _controllerAddress,
        address _phoAddress,
        address _tonAddress
    )
        BondBaseController(_bondDispatcher, _controllerAddress, _phoAddress, _tonAddress)
    {}

    /// @inheritdoc BondBaseController
    function createMarket(bytes calldata params_) external override returns (uint256) {
        MarketParams memory params = abi.decode(params_, (MarketParams));
        uint256 marketId = _createMarket(params);

        // create ERC20 fixed expiry bond token
        IBondFixedExpiryDispatcher(address(bondDispatcher)).deploy(
            params.payoutToken, params.vesting
        );

        return marketId;
    }
}
