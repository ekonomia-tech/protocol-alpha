// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// import "./BaseSetup.t.sol";
// import {PHO} from "../src/contracts/PHO.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// import "src/interfaces/curve/ICurvePool.sol";
// import "src/interfaces/curve/ICurveFactory.sol";
// import {CurveTWAPOracle} from "../src/oracle/CurveTWAPOracle.sol";

// /// @notice basic tests assessing genesis CurveTWAPOracle
// /// @dev for function sigs in metapool, see https://etherscan.io/address/0x497CE58F34605B9944E6b15EcafE6b001206fd25#code
// contract CurveTWAPOracletest is BaseSetup {

//     ICurvePool public curvePool;
//     ICurvePool public fraxBP;
//     ICurvePool public fraxBPPhoMetapool;
//     IERC20 public fraxBPLP;
//     IERC20 public frax;
//     ICurveFactory public curveFactory;
//     ERC20 public fraxBPPhoLP;

//     // ICurveFactory metapoolFactory;
//     CurveTWAPOracle public curveTWAPOracle;

//     /// EVENTS

//     event PriceUpdateThresholdChanged(uint256 priceUpdateThreshold);
//     event TWAPInitialized(uint256[] indexed twap, uint256 indexed blockTimestampLast);
//     event TWAPUpdated(uint256[] indexed twap, uint256 indexed blockTimestampLast);

//     uint256 poolMintAmount = 99750000;
//     uint256 shareBurnAmount = 25 * 10 ** 16;
//     uint256 minPHOOut = 80 * 10 ** 18;

//     /// @notice setup phoFraxBPAddress with 1m FraxBP && 1m PHO from owner
//     function setUp() public {
//         frax = IERC20(fraxAddress);
//         fraxBPLP = IERC20(fraxBPLPToken); // interface with fraxBPLPT
//         fraxBP = ICurvePool(fraxBPAddress); // interface with fraxBPCurvePool (basePool!)
//         curveFactory = ICurveFactory(metaPoolFactoryAddress);
//         address fraxBPPhoMetapoolAddress = _deployFraxBPPHOPool();
//         fraxBPPhoMetapool = ICurvePool(fraxBPPhoMetapoolAddress);
//         fraxBPPhoLP = ERC20(fraxBPPhoMetapool.lp_token());
//         assertEq(fraxBPPhoLP.symbol(), "FRAXBPPHO"); //TODO - delete this check when satisfied
//         curveTWAPOracle = new CurveTWAPOracle(PRICE_THRESHOLD, address(fraxBPPhoMetapool), period);
//         vm.stopPrank();
//     }

//     /// Main CurveTWAPOracle Functional Tests

//     function testSetup() public {

//     }

//     // /// constructor() tests
//     // function testCurveTWAPOracleConstructor() public {
//     //     assertEq(address(curveTWAPOracle.curvePool()), address(curvePool));
//     //     assertEq(curveTWAPOracle.period(),604800);
//     //     assertEq(curveTWAPOracle.priceUpdateThreshold(), 100);
//     //     assertEq(initOracle, false);
//     //     assertEq(curveTWAPOracle.pidController(), address(pid));
//     //     assertEq(tokens[0], phoFraxBPMetapool.coins[0]);
//     //     assertEq(tokens[1], phoFraxBPMetapool.coins[1]);
//     //     assertEq(tokens[0], fraxBPAddress);
//     //     assertEq(tokens[1], address(pho));
//     // }

//     // /// getTWAP() tests

//     // function testCannotGetTWAP() public {
//     //     vm.startPrank(owner);
//     //     phoFraxBPMetapool.remove_liquidity(phoFraxBPMetapool.balanceOf(owner), [0,0]);
//     //     vm.expectRevert("getTWAP(): metapool balance(s) cannot be 0");
//     //     curveTWAPOracle.getTWAP();
//     //     vm.stopPrank();
//     // }

//     // // manual calc of what TWAP && blockTimestampLast should be with current balances after the first getTWAP() and no other txs that affect the metapool balances. 
//     // // check that event is emitted (TWAPInitialized)
//     // function testInitialTWAP() public {
        
//     //     // TODO - calc expected values
//     //     // at this pt 5m in pho and fraxbp
//     //     uint256 expectedTWAP0 = phoFraxBPLP.balanceOf(owner) / FraxBPLP.balanceOf(owner); // TODO - might not have enough precision here or in the oracle - may have to do what uniswap did for other reasons other than gas efficiency
//     //     uint256 expectedTWAP1 = FraxBPLP.balanceOf(owner) / phoFraxBPLP.balanceOf(owner); // TODO - "
//     //     uint256 expectedBlockTimeStamp = block.timestamp;
//     //     uint256 expectedFirstBalances0 = expectedBlockTimeStamp * expectedTWAP0;
//     //     uint256 expectedFirstBalances1 = expectedBlockTimeStamp * expectedTWAP1;

//     //     vm.expectEmit(true, true, false, true);
//     //     emit TWAPInitialized([expectedTWAP0, expectedTWAP1], expectedBlockTimeStamp);
//     //     curveTWAPOracle.getTWAP();
//     //     assertEq(initOracle, true);
//     //     assertEq(expectedFirstBalances0, CurveTWAPOracle.firstBalances(0));
//     //     assertEq(expectedFirstBalances1, CurveTWAPOracle.firstBalances(1));
//     //     assertEq(expectedBlockTimeStamp, curveTWAPOracle.blockTimestampLast());
//     //     assertEq(expectedTWAP0, curveTWAPOracle.twap(0));
//     //     assertEq(expectedTWAP1, curveTWAPOracle.twap(1));
//     // }

//     // /// @notice test getTWAP() after swapping token 0 for token 1
//     // function testTWAPSwapToken0() public {    
//     //     // TODO - Should calculate TWAP manually to compare against what we get      
//     //     // TODO - check emitted TWAPUpdated event
//     //     twapFixture();
//     //     vm.startPrank(owner);
//     //     phoFraxBPMetapool.exchange(0, 1, one_m_d18, tenThousand_d18); // last param should just be msg.sender (caller)

//     //     // TODO - manually calc amount expected to be in emitted events
//     //     curveTWAPOracle.getTWAP();
//     //     assertEq(curveTWAPOracle.blockTimestampLast(), block.timestamp);
//     //     vm.stopPrank();
//     // }

//     // /// @notice test getTWAP() after swapping token 1 for token 0
//     // function testTWAPToken1() public {
//     //     // TODO - Should calculate TWAP manually to compare against what we get      
//     //     // TODO - check emitted TWAPUpdated event
//     //     twapFixture();
//     //     vm.startPrank(owner);
//     //     phoFraxBPMetapool.exchange(1, 0, one_m_d18, tenThousand_d18); // last param should just be msg.sender (caller)

//     //     // TODO - manually calc amount expected to be in emitted events
//     //     curveTWAPOracle.getTWAP();
//     //     assertEq(curveTWAPOracle.blockTimestampLast(), block.timestamp);
//     //     vm.stopPrank();
//     // }

//     // /// consult() tests

//     // function testCannotConsult() public {
//     //     twapFixture();
//     //     CurveTWAPOracle curveTWAPOracle2 = new CurveTWAPOracle(PRICE_THRESHOLD, address(phoFraxBPMetapool), period);
//     //     vm.expectRevert("consult(): CurveTWAPOracle not initialized");
//     //     curveTWAPOracle2.consult(address(fraxBPLP), oneHundred_d18);
//     // }

//     // function testConsultToken0() public {
//     //     twapFixture();
//     //     uint256 token1Out = curveTWAPOracle.consult(address(fraxBPLP), oneHundred_d18);
//     //     uint256 expectedToken1Out = curveTWAPOracle.twap[0] * oneHundred_d18;
//     //     assertEq(expectedToken1Out, token1Out);
//     // }

//     // function testConsultToken1() public {
//     //     twapFixture();
//     //     uint256 token0Out = curveTWAPOracle.consult(address(pho), oneHundred_d18);
//     //     uint256 expectedToken0Out = curveTWAPOracle.twap[1] * oneHundred_d18;
//     //     assertEq(expectedToken0Out, token0Out);
//     // }

//     // function testCannotConsultInvalidToken() public {
//     //     twapFixture();
//     //     uint256 expectedToken0Out = curveTWAPOracle.twap[1] * oneHundred_d18;
//     //     vm.expectRevert("consult(): invalid token");
//     //     curveTWAPOracle.consult(dummyAddress, oneHundred_d18);
//     // }

//     // /// setPriceUpdateThreshold() tests

//     // function testCannotSetPriceThreshold() public {
//     //     vm.expectRevert("_setPriceUpdateThreshold(): priceUpdateThreshold !> 10000");
//     //     curveTWAPOracle.setPriceUpdateThreshold(10001);
//     // }

//     // function testSetPriceUpdateThreshold() public {
//     //     vm.expectEmit(true, false, false, true);
//     //     emit PriceUpdateThresholdChanged(9999);
//     //     curveTWAPOracle.setPriceUpdateThreshold(9999);
//     //     assertEq(curveTWAPOracle.priceUpdateThreshold(), 9999);
//     // }

//     // /// Helpers

//     // /// @notice spin up initialTWAP
//     // /// NOTE - do everything that happens in initial twap, fast forward 1 week in block.timestamp, at setup, we have 5m PHO and 5m FraxBP, so now we can run the initial getTWAP()
//     // function twapFixture() public {
//     //     curveTWAPOracle.getTWAP();
//     //     vm.warp(curveTWAPOracle.blockTimestampLast() + period + 1);
//     //     pho.approve(address(phoFraxBPMetapool), six_m_d18);
//     //     fraxBPLP.approve(address(phoFraxBPMetapool), six_m_d18);
//     // }
// }
