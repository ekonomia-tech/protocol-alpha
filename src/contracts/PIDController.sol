// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import "lib/forge-std/src/Script.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../interfaces/IEUSD.sol";


contract PIDController is AccessControl, Owned {

    IEUSD public EUSD;
        address public creator_address;

    enum PriceChoice { EUSD, SHARE }
    ChainlinkETHUSDPriceConsumer private eth_usd_pricer;
    uint8 private eth_usd_pricer_decimals;
    UniswapPairOracle private EUSDEthOracle;
    UniswapPairOracle private SHAREEthOracle;
    uint8 public constant decimals = 18;
    address public timelock_address; // Governance timelock address
    address public controller_address; // Controller contract to dynamically adjust system parameters automatically
    address public SHARE_address;
    address public EUSD_eth_oracle_address;
    address public SHARE_eth_oracle_address;
    address public weth_address;
    address public eth_usd_consumer_address;

    // Constants for various precisions
    uint256 private constant PRICE_PRECISION = 1e6;
    uint256 public global_collateral_ratio; // 6 decimals of precision, e.g. 924102 = 0.924102
    uint256 public redemption_fee; // 6 decimals of precision, divide by 1000000 in calculations for fee
    uint256 public minting_fee; // 6 decimals of precision, divide by 1000000 in calculations for fee
    uint256 public EUSD_step; // Amount to change the collateralization ratio by upon refreshCollateralRatio()
    uint256 public refresh_cooldown; // Seconds to wait before being able to run refreshCollateralRatio() again
    uint256 public price_target; // The price of EUSD at which the collateral ratio will respond to; this value is only used for the collateral ratio mechanism and not for minting and redeeming which are hardcoded at $1
    uint256 public price_band; // The bound above and below the price target at which the refreshCollateralRatio() will not change the collateral ratio
    bytes32 public constant COLLATERAL_RATIO_PAUSER = keccak256("COLLATERAL_RATIO_PAUSER");
    address public DEFAULT_ADMIN_ADDRESS; 

    bool public collateral_ratio_paused = false;


/// MODIFIERS 

    modifier onlyCollateralRatioPauser() {
        require(hasRole(COLLATERAL_RATIO_PAUSER, msg.sender));
        _;
    }

    modifier onlyByOwnerGovernanceOrController() {
        require(msg.sender == owner || msg.sender == timelock_address || msg.sender == controller_address, "Not the owner, controller, or the governance timelock");
        _;
    }

    constructor (
        IEUSD _EUSD,
        string memory _name,
        string memory _symbol,
        address _creator_address,
        address _timelock_address
    ) public Owned(_creator_address){
        require(_timelock_address != address(0), "Zero address detected"); 
        
        EUSD = _EUSD;
        creator_address = _creator_address;
        timelock_address = _timelock_address;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        DEFAULT_ADMIN_ADDRESS = _msgSender();
        grantRole(COLLATERAL_RATIO_PAUSER, creator_address);
        grantRole(COLLATERAL_RATIO_PAUSER, timelock_address);
        EUSD_step = 2500; // 6 decimals of precision, equal to 0.25%
        global_collateral_ratio = 1000000; // EUSD system starts off fully collateralized (6 decimals of precision)
        refresh_cooldown = 3600; // Refresh cooldown period is set to 1 hour (3600 seconds) at genesis
        price_target = 1000000; // Collateral ratio will adjust according to the $1 price target at genesis
        price_band = 5000; // Collateral ratio will not adjust if between $0.995 and $1.005 at genesis
    }

/// VIEW FUNCTIONS

// Choice = 'EUSD' or 'SHARE' for now
    function oracle_price(PriceChoice choice) internal view returns (uint256) {
        // Get the ETH / USD price first, and cut it down to 1e6 precision
        uint256 __eth_usd_price = uint256(eth_usd_pricer.getLatestPrice()) * (PRICE_PRECISION) / (uint256(10) ** eth_usd_pricer_decimals);
        uint256 price_vs_eth = 0;

        if (choice == PriceChoice.EUSD) {
            price_vs_eth = uint256(EUSDEthOracle.consult(weth_address, PRICE_PRECISION)); // How much EUSD if you put in PRICE_PRECISION WETH
        }
        else if (choice == PriceChoice.SHARE) {
            price_vs_eth = uint256(SHAREEthOracle.consult(weth_address, PRICE_PRECISION)); // How much SHARE if you put in PRICE_PRECISION WETH
        }
        else revert("INVALID PRICE CHOICE. Needs to be either 0 (EUSD) or 1 (SHARE)");

        // Will be in 1e6 format
        return __eth_usd_price.mul(PRICE_PRECISION) / (price_vs_eth);
    }

    // Returns X EUSD = 1 USD
    function EUSD_price() public view returns (uint256) {
        return oracle_price(PriceChoice.EUSD);
    }

    // Returns X SHARE = 1 USD
    function SHARE_price()  public view returns (uint256) {
        return oracle_price(PriceChoice.SHARE);
    }

    function eth_usd_price() public view returns (uint256) {
        return uint256(eth_usd_pricer.getLatestPrice()).mul(PRICE_PRECISION).div(uint256(10) ** eth_usd_pricer_decimals);
    }

    // This is needed to avoid costly repeat calls to different getter functions
    // It is cheaper gas-wise to just dump everything and only use some of the info
    function EUSD_info() public view returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256) {
        return (
            oracle_price(PriceChoice.EUSD), // EUSD_price()
            oracle_price(PriceChoice.SHARE), // SHARE_price()
            totalSupply(), // totalSupply()
            global_collateral_ratio, // global_collateral_ratio()
            globalCollateralValue(), // globalCollateralValue
            minting_fee, // minting_fee()
            redemption_fee, // redemption_fee()
            uint256(eth_usd_pricer.getLatestPrice()) * (PRICE_PRECISION) / (uint256(10) ** eth_usd_pricer_decimals) //eth_usd_price
        );
    }

    // Iterate through all EUSD pools and calculate all value of collateral in all pools globally
    /// TODO - confirm with Niv that this is how we want to go about it 
    function globalCollateralValue() public view returns (uint256) {
        uint256 total_collateral_value_d18 = 0; 

        for (uint i = 0; i < EUSD_pools_array.length; i++){ 
            // Exclude null addresses
            if (EUSD_pools_array[i] != address(0)){
                total_collateral_value_d18 = total_collateral_value_d18 + (EUSDPool(EUSD_pools_array[i]).collatDollarBalance());
            }

        }
        return total_collateral_value_d18;
    }

    /// PUBLIC FUNCTIONS

    // There needs to be a time interval that this can be called. Otherwise it can be called multiple times per expansion.
    uint256 public last_call_time; // Last time the refreshCollateralRatio function was called
    function refreshCollateralRatio() public {
        require(collateral_ratio_paused == false, "Collateral Ratio has been paused");
        uint256 EUSD_price_cur = EUSD_price();
        require(block.timestamp - last_call_time >= refresh_cooldown, "Must wait for the refresh cooldown since last refresh");

        // Step increments are 0.25% (upon genesis, changable by setEUSDStep()) 
        
        if (EUSD_price_cur > price_target.add(price_band)) { //decrease collateral ratio
            if(global_collateral_ratio <= EUSD_step){ //if within a step of 0, go to 0
                global_collateral_ratio = 0;
            } else {
                global_collateral_ratio = global_collateral_ratio.sub(EUSD_step);
            }
        } else if (EUSD_price_cur < price_target.sub(price_band)) { //increase collateral ratio
            if(global_collateral_ratio.add(EUSD_step) >= 1000000){
                global_collateral_ratio = 1000000; // cap collateral ratio at 1.000000
            } else {
                global_collateral_ratio = global_collateral_ratio.add(EUSD_step);
            }
        }

        last_call_time = block.timestamp; // Set the time of the last expansion

        emit CollateralRatioRefreshed(global_collateral_ratio);
    }

    /// RESTRICTED FUNCTIONS

    /// @notice set fee charged per redemption of EUSD (in SHARE) wrt redeem status of fractional token (1t1, fractional, algo)
    function setRedemptionFee(uint256 red_fee) public onlyByOwnerGovernanceOrController {
        redemption_fee = red_fee;

        emit RedemptionFeeSet(red_fee);
    }

    /// @notice set fee charged per minting of EUSD (in SHARE)
    /// TODO - confirm what ERC20 fee is in
    function setMintingFee(uint256 min_fee) public onlyByOwnerGovernanceOrController {
        minting_fee = min_fee;

        emit MintingFeeSet(min_fee);
    }  

    /// @notice CR 'step' to take when adjusting CR
    function setEUSDStep(uint256 _new_step) public onlyByOwnerGovernanceOrController {
        EUSD_step = _new_step;

        emit EUSDStepSet(_new_step);
    }  

     /// @notice CR 'step' to take when adjusting CR
    function setPriceTarget (uint256 _new_price_target) public onlyByOwnerGovernanceOrController {
        price_target = _new_price_target;

        emit PriceTargetSet(_new_price_target);
    }

    /// @notice set time rqd btw CR adjustments
    function setRefreshCooldown(uint256 _new_cooldown) public onlyByOwnerGovernanceOrController {
    	refresh_cooldown = _new_cooldown;

        emit RefreshCooldownSet(_new_cooldown);
    }

    /// @notice setSHAREAddress
    /// TODO - confirm this is needed within this contract
    function setSHAREAddress(address _SHARE_address) public onlyByOwnerGovernanceOrController {
        require(_SHARE_address != address(0), "Zero address detected");

        SHARE_address = _SHARE_address;

        emit SHAREAddressSet(_SHARE_address);
    }

    /// @notice setETHUSD oracle used in CR adjustments
     function setETHUSDOracle(address _eth_usd_consumer_address) public onlyByOwnerGovernanceOrController {
        require(_eth_usd_consumer_address != address(0), "Zero address detected");

        eth_usd_consumer_address = _eth_usd_consumer_address;
        eth_usd_pricer = ChainlinkETHUSDPriceConsumer(eth_usd_consumer_address);
        eth_usd_pricer_decimals = eth_usd_pricer.getDecimals();

        emit ETHUSDOracleSet(_eth_usd_consumer_address);
    }


    /// @notice set Timelock
    /// @dev TODO - confirm what timelock does. How is it different than the RefreshCooldown?
    function setTimelock(address new_timelock) external onlyByOwnerGovernanceOrController {
        require(new_timelock != address(0), "Zero address detected");

        timelock_address = new_timelock;

        emit TimelockSet(new_timelock);
    }

    /// @notice set controller (owner) of this contract
    /// @dev TODO - figure out if this is needed in both EUSD.sol and this contract
    function setController(address _controller_address) external onlyByOwnerGovernanceOrController {
        require(_controller_address != address(0), "Zero address detected");

        controller_address = _controller_address;

        emit ControllerSet(_controller_address);
    }

    /// @notice sets price band that is acceptable before CR adjustment rqd
     function setPriceBand(uint256 _price_band) external onlyByOwnerGovernanceOrController {
        price_band = _price_band;

        emit PriceBandSet(_price_band);
    }

    // Sets the EUSD_ETH Uniswap oracle address 
    function setEUSDEthOracle(address _EUSD_oracle_addr, address _weth_address) public onlyByOwnerGovernanceOrController {
        require((_EUSD_oracle_addr != address(0)) && (_weth_address != address(0)), "Zero address detected");
        EUSD_eth_oracle_address = _EUSD_oracle_addr;
        EUSDEthOracle = UniswapPairOracle(_EUSD_oracle_addr); 
        weth_address = _weth_address;

        emit EUSDETHOracleSet(_EUSD_oracle_addr, _weth_address);
    }

    /// @notice sets the SHARE_ETH Uniswap oracle address 
    function setSHAREEthOracle(address _SHARE_oracle_addr, address _weth_address) public onlyByOwnerGovernanceOrController {
        require((_SHARE_oracle_addr != address(0)) && (_weth_address != address(0)), "Zero address detected");

        SHARE_eth_oracle_address = _SHARE_oracle_addr;
        SHAREEthOracle = UniswapPairOracle(_SHARE_oracle_addr);
        weth_address = _weth_address;

        emit SHAREEthOracleSet(_SHARE_oracle_addr, _weth_address);
    }

    /// @notice turns on and off CR
    function toggleCollateralRatio() public onlyCollateralRatioPauser {
        collateral_ratio_paused = !collateral_ratio_paused;

        emit CollateralRatioToggled(collateral_ratio_paused);
    }
}