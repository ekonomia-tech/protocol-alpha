// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "../interfaces/curve/ICurvePool.sol";
import "../interfaces/oracle/IPHOPriceFeed.sol";

/// @title OracleAggregator - WIP
/// @notice This is a WIP subject to discussion/critique at current stage. Intent is for it to be a pricefeed aggregator for PHO/USD. It may also include algorithmic contingencies, or ability to upgrade for said contingency scenarios.
/// @author Ekonomia: https://github.com/Ekonomia
/// NOTE - all pricefeeds follow IPHOPriceFeed interface
contract OracleAggregator is Ownable{
    address public timelock_address; 
    struct OracleDetails {
        bool registered; // registered or not
        bool isTwap; // if it is twap or not
        uint256 phoPrice; 
        string style; // what style of TWAP is it - Uniswap, Curve, etc. TODO - maybe an enum but how do we customize it more?
        uint256 totalPHOLocked;
    }
    address[] public phoOracleArray; 
    mapping(address => OracleDetails) public phoOracles; // Mapping is also used for faster verification
    uint256 public totalPHOLiquidity;
    uint256 latestAggTwap;
    uint256 avgWeightPHOPrice; // summation of weighted averages
    
    event OracleRegistered(address indexed newOracle);
    event OracleDeregistered(address indexed removedOracle);
    event PHOPriceUpdated(uint256 indexed newPhoPrice, uint256 indexed blockTimestampLast);

    modifier onlyByOwnerGovernanceOrController() {
        require(
            msg.sender == owner() || msg.sender == timelock_address,
            "Not the owner, controller, or the governance timelock"
        );
        _;
    }

    /// @param _timelock_address stop-gap smart contract for maturing on-chain implementation changes
    constructor(
        address _timelock_address
    ) {
        require(_timelock_address != address(0), "Zero address detected");
        timelock_address = _timelock_address;
    }

    /// @notice obtain 'fresh' aggregated pricefeed for PHO/USD from registered oracles
    /// @dev prices are weighted by their respective TVLs wrt total liquidity-provided PHO
    /// @return current aggregated PHO/USD price
    /// NOTE - getPHOUSDPrice() has to return PHO/USD, this is subject to change if we want something different
    function consult() public view returns (uint256) {
        // cycle through array, calculate the price of PHO/USD from them wrt to the TVL they have vs the total circulating TVL of PHO)
        for(uint256 i = 0; i <= phoOracleArray.length; i++) {
            address phoOracleAddress = phoOracleArray[i];
            OracleDetails storage phoOracle = phoOracles(phoOracleAddress); // TODO - fix syntax
            // NOTE - a matcher (not the right term) format would be better here so oracle can cycle through understood 'style' options and match with proper interface instead of if/else statements
            if(phoOracle.style == 'curve'){           
                IPHOPriceFeed curveOracle = IPHOPriceFeed(phoOracleAddress);
                phoOracle.totalPHOLocked = curveOracle.totalPHO();
                uint256[2] calldata _price = curveOracle.getPHOUSDPrice();
                phoOracle.phoPrice = _price[1];
                totalPHOLiquidity += phoOracle.totalPHOLocked;
            }
        }

        for (uint256 i = 0; i <= phoOracleArray.length; i++) {
            address phoOracleAddress = phoOracleArray[i];
            OracleDetails storage phoOracle = phoOracles(phoOracleAddress);
            avgWeightPHOPrice += phoOracle.totalPHOLocked / totalPHOLiquidity;
        }
        emit PHOPriceUpdated(avgWeightPHOPrice, block.timestamp);
        return avgWeightPHOPrice;
    }

    /// @notice add oracle to registry
    /// @param _oracleAddress proposed oracle to register
    /// @param _isTwap whether or not it is a twap oracle
    /// @param _style specific detail for oracle: ex. curve v1 metapool 'curve'
    function registerOracle(address _oracleAddress, bool _isTwap, string calldata _style) public onlyByOwnerGovernanceOrController {
        require(_oracleAddress != address(0), "Zero address detected");
        OracleDetails storage newOracle = phoOracles[_oracleAddress];
        require(!newOracle.registered, "Address already exists");
        newOracle.registered = true;
        newOracle.isTwap = _isTwap;
        phoOracleArray.push(_oracleAddress);
        if (_style == 'curve') {
		    newOracle.style == _style;
            ICurvePool curvePool = ICurvePool(_oracleAddress);
            newOracle.totalPHOLocked = (curvePool.balances(0));
            newOracle.totalPHOLocked = curvePool.totalPHO();
            IPHOPriceFeed curveOracle = IPHOPriceFeed(_oracleAddress);
            uint256[2] calldata _price = curveOracle.getPHOUSDPrice();
            newOracle.phoPrice = _price[0]; 
	    }
        // TODO - future, for pricefeeds that aren't curve, get their phoPrices too, gonna require custom contracts too likely for pricefeeds that will adhere to IPHOPriceFeed.sol
        emit OracleRegistered(_oracleAddress);
    }

    /// @notice removes oracle from registry
    /// @param _oracleAddress proposed oracle to remove from registry
    function deregisterOracle(address _oracleAddress) public onlyByOwnerGovernanceOrController {
        require(_oracleAddress != address(0), "Zero address detected");
        OracleDetails storage newOracle = phoOracles[_oracleAddress];
        require(!newOracle.registered, "Address nonexistent");
        // Delete from the mapping
        delete phoOracles[_oracleAddress];
        for (uint256 i = 0; i < phoOracleArray.length; i++) {
            if (phoOracleArray[i] == _oracleAddress) {
                phoOracleArray[i] = address(0); // This will leave a null in the array and keep the indices the same
                break;
            }
        }
        emit OracleDeregistered(_oracleAddress);
    }
}