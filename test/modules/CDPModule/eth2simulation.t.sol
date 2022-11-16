// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// import "forge-std/Test.sol";

// contract eth2simulation is Test {
//     address user1 = address(100);
//     address stETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
//     address lidoOracle = 0x442af784A788A5bd6F42A01Ebe9F287a871243fb;

//     address[] oracleMembers;
//     Lido lido = Lido(stETH);
//     LidoOracle oracle = LidoOracle(lidoOracle);

//     function setUp() public {
//         vm.deal(user1, 100 * 10 ** 18);
//         vm.prank(user1);
//         lido.submit{value: 1 ether}(address(0));
//         oracleMembers = oracle.getOracleMembers();
//     }

//     function testSomething() public {
//         console.log(lido.balanceOf(user1));
//         for (uint256 i = 0; i < 8; i++) {
//             vm.warp(block.timestamp + (86400 * i + 1));
//             _report(i + 1);

//             console.log(lido.balanceOf(user1));
//         }
//     }

//     function _report(uint256 i) private {
//         (uint256 depositedValidators, uint256 beaconValidators, uint256 beaconBalance) =
//             lido.getBeaconStat();
//         uint256 currentEpoch = oracle.getCurrentEpochId();
//         uint256 expectedEpoch = oracle.getExpectedEpochId();

//         uint256 quorum = oracle.getQuorum();
//         console.log(currentEpoch);
//         console.log(expectedEpoch);

//         uint64 currentBeaconBalance = uint64(beaconBalance * 1000150 / 1000000 / (10 ** 9));

//         console.log(currentBeaconBalance);
//         for (uint256 i = 0; i < quorum; i++) {
//             vm.prank(oracleMembers[i]);
//             oracle.reportBeacon(expectedEpoch, currentBeaconBalance, uint32(beaconValidators));
//         }
//     }
// }

// interface LidoOracle {
//     function getExpectedEpochId() external returns (uint256);
//     function getCurrentEpochId() external returns (uint256);
//     function reportBeacon(uint256 _epochId, uint64 _beaconBalance, uint32 _beaconValidators)
//         external;
//     function getOracleMembers() external view returns (address[] memory);
//     function getQuorum() external view returns (uint256);
// }

// interface Lido {
//     function balanceOf(address account) external returns (uint256);
//     function submit(address _referral) external payable;
//     function getBeaconStat()
//         external
//         view
//         returns (uint256 depositedValidators, uint256 beaconValidators, uint256 beaconBalance);
// }
