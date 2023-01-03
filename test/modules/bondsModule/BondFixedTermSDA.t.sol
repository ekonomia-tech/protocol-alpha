// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "../../BaseSetup.t.sol";
import {BondAggregator} from "@modules/bondsModule/BondAggregator.sol";
import {BondFixedTermSDA} from "@modules/bondsModule/BondFixedTermSDA.sol";
import {BondFixedTermTeller} from "@modules/bondsModule/BondFixedTermTeller.sol";
import {IBondAggregator} from "@bondprotocol/interfaces/IBondAggregator.sol";
import {IBondTeller} from "@bondprotocol/interfaces/IBondTeller.sol";

contract BondFixedTermSDATest is BaseSetup {
    BondAggregator public aggregator;
    BondFixedTermSDA public dispatcher;
    BondFixedTermTeller public teller;

    function setUp() public {
        aggregator = new BondAggregator(address(TONTimelock));
        IBondAggregator ba = IBondAggregator(address(aggregator));

        teller = new BondFixedTermTeller(address(TONTimelock), address(treasury), ba);
        IBondTeller bt = IBondTeller(address(teller));

        dispatcher = new BondFixedTermSDA(address(TONTimelock), bt, ba);
    }

    function testOpen() public {
        console.log(aggregator.TONTimelock());
        console.log(teller.FEE_DECIMALS());
        console.log(dispatcher.allowNewMarkets());
    }
}
