// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "openzeppelin-contracts/contracts/access/AccessControl.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/utils/math/SafeMath.sol";
import "./EUSD.sol";
import "./Share.sol";
import "../oracle/PriceOracle.sol";
import {PoolLibrary} from "../libraries/PoolLibrary.sol";
import {TransferHelper} from "../libraries/TransferHelper.sol";
import "./PIDController.sol";

contract Pool is AccessControl, Ownable {
    using SafeMath for uint256;

    ERC20 private collateral_token;
    address private collateral_address;

    address private eusd_contract_address;
    address private share_contract_address;
    address private timelock_address;
    Share private share;
    EUSD private eusd;
    PIDController private pid;

    PriceOracle public priceOracle;

    uint256 public minting_fee;
    uint256 public redemption_fee;
    uint256 public buyback_fee;
    uint256 public recollat_fee;

    mapping (address => uint256) public redeemShareBalances;
    mapping (address => uint256) public redeemCollateralBalances;
    uint256 public unclaimedPoolCollateral;
    uint256 public unclaimedPoolShare;
    mapping (address => uint256) public lastRedeemed;

    // Constants for various precisions
    uint256 private constant PRICE_PRECISION = 1e6;
    uint256 private constant COLLATERAL_RATIO_PRECISION = 1e6;
    uint256 private constant COLLATERAL_RATIO_MAX = 1e6;

    // Number of decimals needed to get to 18
    uint256 private immutable missing_decimals;

    // Pool_ceiling is the total units of collateral that a pool contract can hold
    uint256 public pool_ceiling = 0;

    // Stores price of the collateral, if price is paused
    uint256 public pausedPrice = 0;

    // Bonus rate on Share minted during recollateralizeEUSD(); 6 decimals of precision, set to 0.75% on genesis
    uint256 public bonus_rate = 7500;

    // Number of blocks to wait before being able to collectRedemption()
    uint256 public redemption_delay = 1;

    // AccessControl Roles
    bytes32 private constant MINT_PAUSER = keccak256("MINT_PAUSER");
    bytes32 private constant REDEEM_PAUSER = keccak256("REDEEM_PAUSER");
    bytes32 private constant BUYBACK_PAUSER = keccak256("BUYBACK_PAUSER");
    bytes32 private constant RECOLLATERALIZE_PAUSER = keccak256("RECOLLATERALIZE_PAUSER");
    bytes32 private constant COLLATERAL_PRICE_PAUSER = keccak256("COLLATERAL_PRICE_PAUSER");
    
    // AccessControl state variables
    bool public mintPaused = false;
    bool public redeemPaused = false;
    bool public recollateralizePaused = false;
    bool public buyBackPaused = false;
    bool public collateralPricePaused = false;

    modifier onlyByOwnGov() {
        require(msg.sender == timelock_address || msg.sender == owner(), "Not owner or timelock");
        _;
    }

    modifier notRedeemPaused() {
        require(redeemPaused == false, "Redeeming is paused");
        _;
    }

    modifier notMintPaused() {
        require(mintPaused == false, "Minting is paused");
        _;
    }

    constructor (
        address _eusd_contract_address,
        address _share_contract_address,
        address _pid_controller_address,
        address _collateral_address,
        address _timelock_address,
        address _price_oracle_address,
        uint256 _pool_ceiling
    ) public {
        require(
            (_eusd_contract_address != address(0))
            && (_share_contract_address != address(0))
            && (_collateral_address != address(0))
            && (_timelock_address != address(0))
        , "Zero address detected"); 
        eusd = EUSD(_eusd_contract_address);
        share = Share(_share_contract_address);
        pid = PIDController(_pid_controller_address);
        eusd_contract_address = _eusd_contract_address;
        share_contract_address = _share_contract_address;
        collateral_address = _collateral_address;
        timelock_address = _timelock_address;
        collateral_token = ERC20(_collateral_address);
        pool_ceiling = _pool_ceiling;
        missing_decimals = uint(18).sub(collateral_token.decimals());

        priceOracle = PriceOracle(_price_oracle_address);
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        grantRole(MINT_PAUSER, timelock_address);
        grantRole(REDEEM_PAUSER, timelock_address);
        grantRole(RECOLLATERALIZE_PAUSER, timelock_address);
        grantRole(BUYBACK_PAUSER, timelock_address);
        grantRole(COLLATERAL_PRICE_PAUSER, timelock_address);
    }

    function collatDollarBalance() public view returns (uint256) {
        if(collateralPricePaused == true){
            return (collateral_token.balanceOf(address(this)).sub(unclaimedPoolCollateral)).mul(10 ** missing_decimals).mul(pausedPrice).div(PRICE_PRECISION);
        } else {
            // Use 
            uint256 eth_usd_price = priceOracle.getETHUSDPrice();

            // This is using UniswapV2PairOracle.
            // collatEthOracle.consult(weth_address, (PRICE_PRECISION * (10 ** missing_decimals)));
            // Use ETH-USD price because initial collats will be stablecoins, so ETH-USD will mimic that
            uint256 eth_collat_price = priceOracle.getETHUSDPrice();

            uint256 collat_usd_price = eth_usd_price.mul(PRICE_PRECISION).div(eth_collat_price);
            return (collateral_token.balanceOf(address(this)).sub(unclaimedPoolCollateral)).mul(10 ** missing_decimals).mul(collat_usd_price).div(PRICE_PRECISION); //.mul(getCollateralPrice()).div(1e6);    
        }
    }

    // Returns the value of excess collateral held in this  pool, compared to what is needed to maintain the global collateral ratio
    function availableExcessCollatDV() public view returns (uint256) {
        uint256 total_supply = eusd.totalSupply();
        uint256 global_collateral_ratio = pid.global_collateral_ratio();
        uint256 global_collat_value = pid.globalCollateralValue();

        // Handles an overcollateralized contract with CR > 1
        if (global_collateral_ratio > COLLATERAL_RATIO_PRECISION) {
            global_collateral_ratio = COLLATERAL_RATIO_PRECISION;
        } 
        
        // Calculates collateral needed to back each 1 eusd with $1 of collateral at current collat ratio
        uint256 required_collat_dollar_value_d18 = (total_supply.mul(global_collateral_ratio)).div(COLLATERAL_RATIO_PRECISION); 
        
        if (global_collat_value > required_collat_dollar_value_d18) {
            return global_collat_value.sub(required_collat_dollar_value_d18);
        }

        return 0;
    }

    // Returns the price of the pool collateral in USD
    // TODO:  after all the oracles are in place, get back to this function nd improve accuracy
    function getCollateralPrice() public view returns (uint256) {
        if(collateralPricePaused == true){
            return pausedPrice;
        } else {
            uint256 eth_usd_price = priceOracle.eth_usd_price();
            return eth_usd_price.mul(PRICE_PRECISION).div(priceOracle.getETHUSDPrice());
        }
    }

    // We separate out the 1t1, fractional and algorithmic minting functions for gas efficiency 
    function mint1t1EUSD(uint256 collateral_amount, uint256 EUSD_out_min) external notMintPaused {
        uint256 collateral_amount_d18 = collateral_amount * (10 ** missing_decimals);

        require(pid.global_collateral_ratio() >= COLLATERAL_RATIO_MAX, "Collateral ratio must be >= 1");
        require((collateral_token.balanceOf(address(this))).sub(unclaimedPoolCollateral).add(collateral_amount) <= pool_ceiling, "[Pool's Closed]: Ceiling reached");
        
        (uint256 eusd_amount_d18) = PoolLibrary.calcMint1t1EUSD(
            getCollateralPrice(),
            collateral_amount_d18
        ); //1 eusd for each $1 worth of collateral

        eusd_amount_d18 = (eusd_amount_d18.mul(uint(1e6).sub(minting_fee))).div(1e6); //remove precision at the end
        require(EUSD_out_min <= eusd_amount_d18, "Slippage limit reached");

        TransferHelper.safeTransferFrom(address(collateral_token), msg.sender, address(this), collateral_amount);
        eusd.pool_mint(msg.sender, eusd_amount_d18);
    }

    // Will fail if fully collateralized or fully algorithmic
    // > 0% and < 100% collateral-backed
    function mintFractionalEUSD(uint256 collateral_amount, uint256 share_amount, uint256 EUSD_out_min) external notMintPaused {
        uint256 share_price = priceOracle.getShareUSDPrice();
        uint256 global_collateral_ratio = pid.global_collateral_ratio();

        require(global_collateral_ratio < COLLATERAL_RATIO_MAX && global_collateral_ratio > 0, "Collateral ratio needs to be between .000001 and .999999");
        require(collateral_token.balanceOf(address(this)).sub(unclaimedPoolCollateral).add(collateral_amount) <= pool_ceiling, "Pool ceiling reached, no more eusd can be minted with this collateral");

        uint256 collateral_amount_d18 = collateral_amount * (10 ** missing_decimals);
        PoolLibrary.MintFF_Params memory input_params = PoolLibrary.MintFF_Params(
            share_price,
            getCollateralPrice(),
            share_amount,
            collateral_amount_d18,
            global_collateral_ratio
        );

        (uint256 mint_amount, uint256 share_needed) = PoolLibrary.calcMintFractionalEUSD(input_params);

        mint_amount = (mint_amount.mul(uint(1e6).sub(minting_fee))).div(1e6);
        require(EUSD_out_min <= mint_amount, "Slippage limit reached");
        require(share_needed <= share_amount, "Not enough Share inputted");

        share.pool_burn_from(msg.sender, share_needed);
        TransferHelper.safeTransferFrom(address(collateral_token), msg.sender, address(this), collateral_amount);
        eusd.pool_mint(msg.sender, mint_amount);
    }

    // Redeem collateral. 100% collateral-backed
    function redeem1t1EUSD(uint256 eusd_amount, uint256 COLLATERAL_out_min) external notRedeemPaused {
        require(pid.global_collateral_ratio() == COLLATERAL_RATIO_MAX, "Collateral ratio must be == 1");

        // Need to adjust for decimals of collateral
        uint256 eusd_amount_precision = eusd_amount.div(10 ** missing_decimals);
        (uint256 collateral_needed) = PoolLibrary.calcRedeem1t1EUSD(
            getCollateralPrice(),
            eusd_amount_precision
        );

        collateral_needed = (collateral_needed.mul(uint(1e6).sub(redemption_fee))).div(1e6);
        require(collateral_needed <= collateral_token.balanceOf(address(this)).sub(unclaimedPoolCollateral), "Not enough collateral in pool");
        require(COLLATERAL_out_min <= collateral_needed, "Slippage limit reached");

        redeemCollateralBalances[msg.sender] = redeemCollateralBalances[msg.sender].add(collateral_needed);
        unclaimedPoolCollateral = unclaimedPoolCollateral.add(collateral_needed);
        lastRedeemed[msg.sender] = block.number;
        
        // Move all external functions to the end
        eusd.pool_burn_from(msg.sender, eusd_amount);
    }

    // Will fail if fully collateralized or algorithmic
    // Redeem eusd for collateral and Share. > 0% and < 100% collateral-backed
    function redeemFractionalEUSD(uint256 eusd_amount, uint256 Share_out_min, uint256 COLLATERAL_out_min) external notRedeemPaused {
        uint256 share_price = priceOracle.getShareUSDPrice();
        uint256 global_collateral_ratio = pid.global_collateral_ratio();

        require(global_collateral_ratio < COLLATERAL_RATIO_MAX && global_collateral_ratio > 0, "Collateral ratio needs to be between .000001 and .999999");
        uint256 col_price_usd = getCollateralPrice();

        uint256 eusd_amount_post_fee = (eusd_amount.mul(uint(1e6).sub(redemption_fee))).div(PRICE_PRECISION);

        uint256 share_dollar_value_d18 = eusd_amount_post_fee.sub(eusd_amount_post_fee.mul(global_collateral_ratio).div(PRICE_PRECISION));
        uint256 share_amount = share_dollar_value_d18.mul(PRICE_PRECISION).div(share_price);

        // Need to adjust for decimals of collateral
        uint256 eusd_amount_precision = eusd_amount_post_fee.div(10 ** missing_decimals);
        uint256 collateral_dollar_value = eusd_amount_precision.mul(global_collateral_ratio).div(PRICE_PRECISION);
        uint256 collateral_amount = collateral_dollar_value.mul(PRICE_PRECISION).div(col_price_usd);


        require(collateral_amount <= collateral_token.balanceOf(address(this)).sub(unclaimedPoolCollateral), "Not enough collateral in pool");
        require(COLLATERAL_out_min <= collateral_amount, "Slippage limit reached [collateral]");
        require(Share_out_min <= share_amount, "Slippage limit reached [Share]");

        redeemCollateralBalances[msg.sender] = redeemCollateralBalances[msg.sender].add(collateral_amount);
        unclaimedPoolCollateral = unclaimedPoolCollateral.add(collateral_amount);

        redeemShareBalances[msg.sender] = redeemShareBalances[msg.sender].add(share_amount);
        unclaimedPoolShare = unclaimedPoolShare.add(share_amount);

        lastRedeemed[msg.sender] = block.number;
        
        // Move all external functions to the end
        eusd.pool_burn_from(msg.sender, eusd_amount);
        share.pool_mint(address(this), share_amount);
    }

    function collectRedemption() external {
        require((lastRedeemed[msg.sender].add(redemption_delay)) <= block.number, "Must wait for redemption_delay blocks before collecting redemption");
        bool sendShare = false;
        bool sendCollateral = false;
        uint ShareAmount = 0;
        uint CollateralAmount = 0;

        // Use Checks-Effects-Interactions pattern
        if(redeemShareBalances[msg.sender] > 0){
            ShareAmount = redeemShareBalances[msg.sender];
            redeemShareBalances[msg.sender] = 0;
            unclaimedPoolShare = unclaimedPoolShare.sub(ShareAmount);

            sendShare = true;
        }
        
        if(redeemCollateralBalances[msg.sender] > 0){
            CollateralAmount = redeemCollateralBalances[msg.sender];
            redeemCollateralBalances[msg.sender] = 0;
            unclaimedPoolCollateral = unclaimedPoolCollateral.sub(CollateralAmount);

            sendCollateral = true;
        }

        if(sendShare){
            TransferHelper.safeTransfer(address(share), msg.sender, ShareAmount);
        }
        if(sendCollateral){
            TransferHelper.safeTransfer(address(collateral_token), msg.sender, CollateralAmount);
        }
    }


    // When the protocol is recollateralizing, we need to give a discount of Share to hit the new CR target
    // Thus, if the target collateral ratio is higher than the actual value of collateral, minters get Share for adding collateral
    // This function simply rewards anyone that sends collateral to a pool with the same amount of Share + the bonus rate
    // Anyone can call this function to recollateralize the protocol and take the extra Share value from the bonus rate as an arb opportunity
    function recollateralizeEUSD(uint256 collateral_amount, uint256 Share_out_min) external {
        require(recollateralizePaused == false, "Recollateralize is paused");
        uint256 collateral_amount_d18 = collateral_amount * (10 ** missing_decimals);
        uint256 share_price = priceOracle.getShareUSDPrice();
        uint256 eusd_total_supply = eusd.totalSupply();
        uint256 global_collateral_ratio = pid.global_collateral_ratio();
        uint256 global_collat_value = pid.globalCollateralValue();

        (uint256 collateral_units, uint256 amount_to_recollat) = PoolLibrary.calcRecollateralizeEUSDInner(
            collateral_amount_d18,
            getCollateralPrice(),
            global_collat_value,
            eusd_total_supply,
            global_collateral_ratio
        ); 

        uint256 collateral_units_precision = collateral_units.div(10 ** missing_decimals);

        uint256 share_paid_back = amount_to_recollat.mul(uint(1e6).add(bonus_rate).sub(recollat_fee)).div(share_price);

        require(Share_out_min <= share_paid_back, "Slippage limit reached");
        TransferHelper.safeTransferFrom(address(collateral_token), msg.sender, address(this), collateral_units_precision);
        share.pool_mint(msg.sender, share_paid_back);
        
    }

    // Function can be called by an Share holder to have the protocol buy back Share with excess collateral value from a desired collateral pool
    // This can also happen if the collateral ratio > 1
    function buyBackShare(uint256 Share_amount, uint256 COLLATERAL_out_min) external {
        require(buyBackPaused == false, "Buyback is paused");
        uint256 share_price = priceOracle.getShareUSDPrice();
    
        PoolLibrary.BuybackShare_Params memory input_params = PoolLibrary.BuybackShare_Params(
            availableExcessCollatDV(),
            share_price,
            getCollateralPrice(),
            Share_amount
        );

        (uint256 collateral_equivalent_d18) = (PoolLibrary.calcBuyBackShare(input_params)).mul(uint(1e6).sub(buyback_fee)).div(1e6);
        uint256 collateral_precision = collateral_equivalent_d18.div(10 ** missing_decimals);

        require(COLLATERAL_out_min <= collateral_precision, "Slippage limit reached");
        // Give the sender their desired collateral and burn the Share
        share.pool_burn_from(msg.sender, Share_amount);
        TransferHelper.safeTransfer(address(collateral_token), msg.sender, collateral_precision);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function toggleMinting() external {
        require(hasRole(MINT_PAUSER, msg.sender));
        mintPaused = !mintPaused;

        emit MintingToggled(mintPaused);
    }

    function toggleRedeeming() external {
        require(hasRole(REDEEM_PAUSER, msg.sender));
        redeemPaused = !redeemPaused;

        emit RedeemingToggled(redeemPaused);
    }

    function toggleRecollateralize() external {
        require(hasRole(RECOLLATERALIZE_PAUSER, msg.sender));
        recollateralizePaused = !recollateralizePaused;

        emit RecollateralizeToggled(recollateralizePaused);
    }
    
    function toggleBuyBack() external {
        require(hasRole(BUYBACK_PAUSER, msg.sender));
        buyBackPaused = !buyBackPaused;

        emit BuybackToggled(buyBackPaused);
    }

    function toggleCollateralPrice(uint256 _new_price) external {
        require(hasRole(COLLATERAL_PRICE_PAUSER, msg.sender));
        // If pausing, set paused price; else if unpausing, clear pausedPrice
        if(collateralPricePaused == false){
            pausedPrice = _new_price;
        } else {
            pausedPrice = 0;
        }
        collateralPricePaused = !collateralPricePaused;

        emit CollateralPriceToggled(collateralPricePaused);
    }

    // Combined into one function due to 24KiB contract memory limit
    function setPoolParameters(uint256 new_ceiling, uint256 new_bonus_rate, uint256 new_redemption_delay, uint256 new_mint_fee, uint256 new_redeem_fee, uint256 new_buyback_fee, uint256 new_recollat_fee) external onlyByOwnGov {
        pool_ceiling = new_ceiling;
        bonus_rate = new_bonus_rate;
        redemption_delay = new_redemption_delay;
        minting_fee = new_mint_fee;
        redemption_fee = new_redeem_fee;
        buyback_fee = new_buyback_fee;
        recollat_fee = new_recollat_fee;

        emit PoolParametersSet(new_ceiling, new_bonus_rate, new_redemption_delay, new_mint_fee, new_redeem_fee, new_buyback_fee, new_recollat_fee);
    }

    function setTimelock(address new_timelock) external onlyByOwnGov {
        timelock_address = new_timelock;

        emit TimelockSet(new_timelock);
    }

    /* ========== EVENTS ========== */

    event PoolParametersSet(uint256 new_ceiling, uint256 new_bonus_rate, uint256 new_redemption_delay, uint256 new_mint_fee, uint256 new_redeem_fee, uint256 new_buyback_fee, uint256 new_recollat_fee);
    event TimelockSet(address new_timelock);
    event MintingToggled(bool toggled);
    event RedeemingToggled(bool toggled);
    event RecollateralizeToggled(bool toggled);
    event BuybackToggled(bool toggled);
    event CollateralPriceToggled(bool toggled);


}   