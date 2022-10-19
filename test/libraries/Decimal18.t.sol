// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "src/libraries/Decimal18.sol";

contract Decimal18Test is Test {
    using Decimal18 for decimal18;
    using Decimal18 for uint256;

    function test_Decimal18_wrap_1() public {
        uint256 val = 1;
        assertEq(val.toDecimal18().toUint256(), val);
    }

    function test_Decimal18_wrap_2() public {
        uint256 val = 1e6;
        assertEq(val.toDecimal18({decimals: 6}).toUint256(), 1 ether);
    }

    function test_Decimal18_add() public {
        decimal18 A = decimal18.wrap(2 ether);
        decimal18 B = decimal18.wrap(3 ether);
        assertEq(A.add(B).toUint256(), 5 ether);
    }

    function test_Decimal18_mul() public {
        decimal18 A = decimal18.wrap(2 ether);
        decimal18 B = decimal18.wrap(3 ether);
        assertEq(A.mul(B).toUint256(), 6 ether);
    }

    function test_Decimal18_div() public {
        decimal18 A = decimal18.wrap(6 ether);
        decimal18 B = decimal18.wrap(3 ether);
        assertEq(A.div(B).toUint256(), 2 ether);
    }
}
