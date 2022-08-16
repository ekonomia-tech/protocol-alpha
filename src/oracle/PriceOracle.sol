// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;


contract PriceOracle {

    uint256 public eth_usd_price;
    uint256 public share_eth_price;
    uint256 public share_usd_price;
    uint256 public eusd_eth_price;

    constructor() {
        eth_usd_price = 2000 * 10 ** 18;
        share_eth_price = 200 * 10 ** 18;
        share_usd_price = 10 ** 18;
        eusd_eth_price = 2000 * 10 ** 18;
    }

    function getETHUSDPrice() public view returns(uint256){
        return eth_usd_price;
    }

    function getShareETHPrice() public view returns(uint256) {
        return share_eth_price;
    }

    function getShareUSDPrice() public view returns(uint256) {
        return share_usd_price;
    }
 
    function getEUSDETHPrice() public view returns(uint256) {
        return eusd_eth_price;
    }


    function setETHUSDPrice(uint256 _price) public {
        eth_usd_price = _price;
    }

    function setShareETHPrice(uint256 _price) public {
        share_eth_price = _price;
    }

    function setShareUSDPrice(uint256 _price) public {
        share_usd_price = _price;
    }

    function setEUSDETHPrice(uint256 _price) public {
        eusd_eth_price = _price;
    }

}