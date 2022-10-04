// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.8;

type decimal18 is uint256;

/// @title Library for working with D18 values
library Decimal18 {
    using Decimal18 for decimal18;
    using Decimal18 for uint256;

    uint256 constant ONE_decimal18 = 1e18;

    function toDecimal18(uint256 value) internal pure returns (decimal18) {
        return decimal18.wrap(value);
    }

    function toDecimal18(uint256 value, uint8 decimals) internal pure returns (decimal18) {
        if (decimals < 18) {
            return decimal18.wrap(value * 10 ** (18 - decimals));
        } else if (decimals > 18) {
            return decimal18.wrap(value * 10 ** (decimals - 18));
        } else {
            return decimal18.wrap(value);
        }
    }

    function toUint256(decimal18 value) internal pure returns (uint256) {
        return decimal18.unwrap(value);
    }

    function add(decimal18 a, decimal18 b) internal pure returns (decimal18) {
        uint256 _a = decimal18.unwrap(a);
        uint256 _b = decimal18.unwrap(b);
        return decimal18.wrap(_a + _b);
    }

    function mul(decimal18 a, decimal18 b) internal pure returns (decimal18) {
        uint256 _a = decimal18.unwrap(a);
        uint256 _b = decimal18.unwrap(b);
        return decimal18.wrap(_a * _b / ONE_decimal18);
    }

    function div(decimal18 num, decimal18 den) internal pure returns (decimal18) {
        uint256 _num = decimal18.unwrap(num);
        uint256 _den = decimal18.unwrap(den);
        return decimal18.wrap(_num * ONE_decimal18 / _den);
    }
}
