// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseSetup.t.sol";
import {EUSD} from "../src/contracts/EUSD.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/interfaces/ICurve.sol";
import {CurveTWAPOracle} from "../src/oracle/CurveTWAPOracle.sol";

contract CurveTWAPOracletest is BaseSetup {

    ICurve fraxBP;
    ICurve eusdFraxBPMetapool;
    address eusdFraxBPAddress;
    ICurveFactory metapoolFactory;
    IERC20 eusdFraxBPLP;
    IERC20 FraxBPLP;
    CurveTWAPOracle curveTWAPOracle;

    address public constant fraxBPLPToken = 0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC;
    address public constant fraxBPAddress = 0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2;
    address public constant metaPoolFactoryAddress = 0xB9fC157394Af804a3578134A6585C0dc9cc990d4;
    /// EVENTS

    event PriceUpdateThresholdChanged(uint256 priceUpdateThreshold);
    event TWAPInitialized(uint256[] indexed twap, uint256 indexed blockTimestampLast);
    event TWAPUpdated(uint256[] indexed twap, uint256 indexed blockTimestampLast);

    uint256 poolMintAmount = 99750000;
    uint256 shareBurnAmount = 25 * 10 ** 16;
    uint256 minEUSDOut = 80 * 10 ** 18;

    /// @notice setup eusdFraxBPAddress with 5m FraxBP && 5m EUSD from owner
    function setUp() public {

        FraxBPLP = IERC20(fraxBPLPToken); // lp token erc20 contract
        fraxBP = ICurve(fraxBPAddress); // metapool contract
        metapoolFactory = ICurveFactory(metaPoolFactoryAddress);

        vm.startPrank(owner);

        usdc.approve(address(fraxBP), five_m_d6); // TODO- approve a lot - 5m USDC
        uint256 allowance = usdc.allowance(owner, address(fraxBP));
        console.log("fraxBP allowance for usdc: %s", allowance);

        // TODO - FIX THIS ERROR WITH ARRAY INPUT PARAMS
        uint256[] memory metaLiquidity = new uint256[](2);
        metaLiquidity = [0, five_m_d6];
        fraxBP.add_liquidity(metaLiquidity,0);
        
        // check that the balances have changed for user's FraxBP LP tokens
        uint256 callerFraxBPBalance = FraxBPLP.balanceOf(owner);
        console.log("callerFraxBPBalance: %s", callerFraxBPBalance);

        /// deploy FRAXBP-EUSD metapool
        // TODO - not sure if the address returned is the metapool address, if so, we don't have to do address(eusdFraxBPAddress).
        eusdFraxBPAddress = metapoolFactory.deploy_metapool(address(fraxBP), "FRAXBP-EUSD", "FRAXBPEUSD", address(eusd), 10, 4000000, 295330021868150247895544788229857886848430702695);

        eusdFraxBPMetapool = ICurve(eusdFraxBPAddress);
        
        assertEq(eusdFraxBPMetapool.symbol(), "FRAXBPEUSD"); //check that symbol is setup and metapool deployed.

        eusd.approve(address(eusdFraxBPMetapool), six_m_d18);
        fraxBPLP.approve(address(eusdFraxBPMetapool), six_m_d18);
        eusdFraxBPMetapool.add_liquidity([five_m_d18, five_m_d18], 0);

        curveTWAPOracle = new CurveTWAPOracle(PRICE_THRESHOLD, address(eusdFraxBPMetapool), period);

        vm.stopPrank();
    }

    /// Main CurveTWAPOracle Functional Tests

    /// constructor() tests
    
    /// @notice check GCV when only one EUSDPool compared to actual single pool's worth of collateral in protocol
    function testFullGlobalCollateralValue() public {
    }

    /// getTWAP() tests
    
    /// consult() tests

    /// setPriceUpdateThreshold() tests

    /// Helpers
}
