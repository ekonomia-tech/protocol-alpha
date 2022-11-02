// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

contract DummyOracle {
    uint256 public eth_usd_price;
    uint256 public eth_ton_price;
    uint256 public ton_usd_price;
    uint256 public eth_pho_price;
    uint256 public pho_usd_price;
    uint256 public usdc_usd_price;
    uint256 public mpl_pho_price;

    constructor() {
        eth_usd_price = 2000 * 10 ** 6; // 2000 usd/eth
        eth_ton_price = 200 * 10 ** 18; // 200 TON/eth
        eth_pho_price = 2000 * 10 ** 18; // 2000 pho/eth
        ton_usd_price = 10 ** 6; // 10 dollar/ton
        pho_usd_price = 10 ** 6;
        usdc_usd_price = 10 ** 6;
        mpl_pho_price = 15 * 10 ** 18; // 15 pho/mpl
    }

    function getETHUSDPrice() public view returns (uint256) {
        return eth_usd_price;
    }

    function getETHTONPrice() public view returns (uint256) {
        return eth_ton_price;
    }

    function getTONUSDPrice() public view returns (uint256) {
        return ton_usd_price;
    }

    function getETHPHOPrice() public view returns (uint256) {
        return eth_pho_price;
    }

    function getPHOUSDPrice() public view returns (uint256) {
        return pho_usd_price;
    }

    function getUSDCUSDPrice() public view returns (uint256) {
        return usdc_usd_price;
    }

    function getMPLPHOPrice() public view returns (uint256) {
        return mpl_pho_price;
    }

    function setETHUSDPrice(uint256 _price) public {
        eth_usd_price = _price;
    }

    function setETHTONPrice(uint256 _price) public {
        eth_ton_price = _price;
    }

    function setTONUSDPrice(uint256 _price) public {
        ton_usd_price = _price;
    }

    function setETHPHOPrice(uint256 _price) public {
        eth_pho_price = _price;
    }

    function setPHOUSDPrice(uint256 _price) public {
        pho_usd_price = _price;
    }

    function setUSDCUSDPrice(uint256 _price) public {
        usdc_usd_price = _price;
    }

    function setMPLPHOPrice(uint256 _price) public {
        mpl_pho_price = _price;
    }
}
