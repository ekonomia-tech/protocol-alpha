// SPDX-License-Identifier: GPL-3.0-or-later
// Inspired by Frax
// https://github.com/FraxFinance/frax-solidity/blob/7cbe89981ffa5d3cd0eeaf62dd1489c3276de0e4/src/hardhat/contracts/Frax/Pools/FraxPool.sol
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./PHO.sol";
import "./TON.sol";
import "../oracle/DummyOracle.sol";
import {PoolLibrary} from "../libraries/PoolLibrary.sol";
import {TransferHelper} from "../libraries/TransferHelper.sol";
import "./PIDController.sol";

contract Pool is AccessControl, Ownable {
    using SafeMath for uint256;

    ERC20 private collateral_token;
    address private collateral_address;

    address private pho_contract_address;
    address private ton_contract_address;
    address private timelock_address;
    TON private ton;
    PHO private pho;
    PIDController private pid;

    DummyOracle public priceOracle;

    uint256 public minting_fee;
    uint256 public redemption_fee;
    uint256 public buyback_fee;
    uint256 public recollat_fee;

    mapping(address => uint256) public redeemTONBalances;
    mapping(address => uint256) public redeemCollateralBalances;
    uint256 public unclaimedPoolCollateral;
    uint256 public unclaimedPoolTON;
    mapping(address => uint256) public lastRedeemed;

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

    // Bonus rate on TON minted during recollateralizePHO(); 6 decimals of precision, set to 0.75% on genesis
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

    constructor(
        address _pho_contract_address,
        address _ton_contract_address,
        address _pid_controller_address,
        address _collateral_address,
        address _timelock_address,
        address _price_oracle_address,
        uint256 _pool_ceiling
    )
        public
    {
        require(
            (_pho_contract_address != address(0)) && (_ton_contract_address != address(0))
                && (_collateral_address != address(0)) && (_timelock_address != address(0)),
            "Zero address detected"
        );
        pho = PHO(_pho_contract_address);
        ton = TON(_ton_contract_address);
        pid = PIDController(_pid_controller_address);
        pho_contract_address = _pho_contract_address;
        ton_contract_address = _ton_contract_address;
        collateral_address = _collateral_address;
        timelock_address = _timelock_address;
        collateral_token = ERC20(_collateral_address);
        pool_ceiling = _pool_ceiling;
        missing_decimals = uint256(18).sub(collateral_token.decimals());

        priceOracle = DummyOracle(_price_oracle_address);
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        grantRole(MINT_PAUSER, timelock_address);
        grantRole(REDEEM_PAUSER, timelock_address);
        grantRole(RECOLLATERALIZE_PAUSER, timelock_address);
        grantRole(BUYBACK_PAUSER, timelock_address);
        grantRole(COLLATERAL_PRICE_PAUSER, timelock_address);
    }

    function collatDollarBalance() public view returns (uint256) {
        if (collateralPricePaused == true) {
            return (collateral_token.balanceOf(address(this)).sub(unclaimedPoolCollateral)).mul(
                10 ** missing_decimals
            ).mul(pausedPrice).div(PRICE_PRECISION);
        } else {
            // Use
            uint256 eth_usd_price = priceOracle.getETHUSDPrice();

            // This is using UniswapV2PairOracle.
            // collatEthOracle.consult(weth_address, (PRICE_PRECISION * (10 ** missing_decimals)));
            // Use ETH-USD price because initial collats will be stablecoins, so ETH-USD will mimic that
            uint256 eth_collat_price = priceOracle.getETHUSDPrice();

            uint256 collat_usd_price = eth_usd_price.mul(PRICE_PRECISION).div(eth_collat_price);
            return (collateral_token.balanceOf(address(this)).sub(unclaimedPoolCollateral)).mul(
                10 ** missing_decimals
            ).mul(collat_usd_price).div(PRICE_PRECISION); //.mul(getCollateralPrice()).div(1e6);
        }
    }

    // Returns the value of excess collateral held in this  pool, compared to what is needed to maintain the global collateral ratio
    function availableExcessCollatDV() public view returns (uint256) {
        uint256 total_supply = pho.totalSupply();
        uint256 global_collateral_ratio = pid.global_collateral_ratio();
        uint256 global_collat_value = pid.globalCollateralValue();

        // Handles an overcollateralized contract with CR > 1
        if (global_collateral_ratio > COLLATERAL_RATIO_PRECISION) {
            global_collateral_ratio = COLLATERAL_RATIO_PRECISION;
        }

        // Calculates collateral needed to back each 1 pho with $1 of collateral at current collat ratio
        uint256 required_collat_dollar_value_d18 =
            (total_supply.mul(global_collateral_ratio)).div(COLLATERAL_RATIO_PRECISION);

        if (global_collat_value > required_collat_dollar_value_d18) {
            return global_collat_value.sub(required_collat_dollar_value_d18);
        }

        return 0;
    }

    // Returns the price of the pool collateral in USD
    // currently returns USDC price only.
    // TODO:  after all the oracles are in place, get back to this function nd improve accuracy
    function getCollateralPrice() public view returns (uint256) {
        return priceOracle.getUSDCUSDPrice();
        // if(collateralPricePaused == true){
        //     return pausedPrice;
        // } else {
        //     uint256 eth_usd_price = priceOracle.eth_usd_price();
        //     return eth_usd_price.mul(PRICE_PRECISION).div(priceOracle.getETHUSDPrice());
        // }
    }

    // We separate out the 1t1, fractional and algorithmic minting functions for gas efficiency
    function mint1t1PHO(uint256 collateral_amount, uint256 PHO_out_min) external notMintPaused {
        uint256 collateral_amount_d18 = collateral_amount * (10 ** missing_decimals);

        require(
            pid.global_collateral_ratio() >= COLLATERAL_RATIO_MAX, "Collateral ratio must be >= 1"
        );
        require(
            (collateral_token.balanceOf(address(this))).sub(unclaimedPoolCollateral).add(
                collateral_amount
            ) <= pool_ceiling,
            "[Pool's Closed]: Ceiling reached"
        );

        (uint256 pho_amount_d18) =
            PoolLibrary.calcMint1t1PHO(getCollateralPrice(), collateral_amount_d18); //1 pho for each $1 worth of collateral

        pho_amount_d18 = (pho_amount_d18.mul(uint256(1e6).sub(minting_fee))).div(1e6); //remove precision at the end
        require(PHO_out_min <= pho_amount_d18, "Slippage limit reached");

        TransferHelper.safeTransferFrom(
            address(collateral_token), msg.sender, address(this), collateral_amount
        );
        pho.pool_mint(msg.sender, pho_amount_d18);
    }

    // Will fail if fully collateralized or fully algorithmic
    // > 0% and < 100% collateral-backed
    function mintFractionalPHO(uint256 collateral_amount, uint256 ton_amount, uint256 PHO_out_min)
        external
        notMintPaused
    {
        uint256 ton_price = priceOracle.getTONUSDPrice();
        uint256 global_collateral_ratio = pid.global_collateral_ratio();

        require(
            global_collateral_ratio < COLLATERAL_RATIO_MAX && global_collateral_ratio > 0,
            "Collateral ratio needs to be between .000001 and .999999"
        );
        require(
            collateral_token.balanceOf(address(this)).sub(unclaimedPoolCollateral).add(
                collateral_amount
            ) <= pool_ceiling,
            "Pool ceiling reached, no more pho can be minted with this collateral"
        );

        uint256 collateral_amount_d18 = collateral_amount * (10 ** missing_decimals);
        PoolLibrary.MintFF_Params memory input_params = PoolLibrary.MintFF_Params(
            ton_price,
            getCollateralPrice(),
            ton_amount,
            collateral_amount_d18,
            global_collateral_ratio
        );

        (uint256 mint_amount, uint256 ton_needed) = PoolLibrary.calcMintFractionalPHO(input_params);

        mint_amount = (mint_amount.mul(uint256(1e6).sub(minting_fee))).div(1e6);
        require(PHO_out_min <= mint_amount, "Slippage limit reached");
        require(ton_needed <= ton_amount, "Not enough TON inputted");

        ton.pool_burn_from(msg.sender, ton_needed);
        TransferHelper.safeTransferFrom(
            address(collateral_token), msg.sender, address(this), collateral_amount
        );
        pho.pool_mint(msg.sender, mint_amount);
    }

    // 0% collateral-backed
    // function mintAlgorithmicPHO(uint256 ton_amount_d18, uint256 PHO_out_min) external notMintPaused {
    //     uint256 ton_price = priceOracle.getTONUSDPrice();
    //     require(pid.global_collateral_ratio() == 0, "Collateral ratio must be 0");

    //     (uint256 pho_amount_d18) = PoolLibrary.calcMintAlgorithmicPHO(
    //         ton_price, // X ton / 1 USD
    //         ton_amount_d18
    //     );

    //     pho_amount_d18 = (pho_amount_d18.mul(uint(1e6).sub(minting_fee))).div(1e6);
    //     require(PHO_out_min <= pho_amount_d18, "Slippage limit reached");

    //     ton.pool_burn_from(msg.sender, ton_amount_d18);
    //     pho.pool_mint(msg.sender, pho_amount_d18);
    // }

    // Redeem collateral. 100% collateral-backed
    function redeem1t1PHO(uint256 pho_amount, uint256 COLLATERAL_out_min)
        external
        notRedeemPaused
    {
        require(
            pid.global_collateral_ratio() == COLLATERAL_RATIO_MAX, "Collateral ratio must be == 1"
        );

        // Need to adjust for decimals of collateral
        uint256 pho_amount_precision = pho_amount.div(10 ** missing_decimals);
        (uint256 collateral_needed) =
            PoolLibrary.calcRedeem1t1PHO(getCollateralPrice(), pho_amount_precision);

        collateral_needed = (collateral_needed.mul(uint256(1e6).sub(redemption_fee))).div(1e6);
        require(
            collateral_needed
                <= collateral_token.balanceOf(address(this)).sub(unclaimedPoolCollateral),
            "Not enough collateral in pool"
        );
        require(COLLATERAL_out_min <= collateral_needed, "Slippage limit reached");

        redeemCollateralBalances[msg.sender] =
            redeemCollateralBalances[msg.sender].add(collateral_needed);
        unclaimedPoolCollateral = unclaimedPoolCollateral.add(collateral_needed);
        lastRedeemed[msg.sender] = block.number;

        // Move all external functions to the end
        pho.pool_burn_from(msg.sender, pho_amount);
    }

    // Will fail if fully collateralized or algorithmic
    // Redeem pho for collateral and TON. > 0% and < 100% collateral-backed
    function redeemFractionalPHO(
        uint256 pho_amount,
        uint256 TON_out_min,
        uint256 COLLATERAL_out_min
    )
        external
        notRedeemPaused
    {
        uint256 ton_price = priceOracle.getTONUSDPrice();
        uint256 global_collateral_ratio = pid.global_collateral_ratio();

        require(
            global_collateral_ratio < COLLATERAL_RATIO_MAX && global_collateral_ratio > 0,
            "Collateral ratio needs to be between .000001 and .999999"
        );
        uint256 col_price_usd = getCollateralPrice();

        uint256 pho_amount_post_fee =
            (pho_amount.mul(uint256(1e6).sub(redemption_fee))).div(PRICE_PRECISION);

        uint256 ton_dollar_value_d18 = pho_amount_post_fee.sub(
            pho_amount_post_fee.mul(global_collateral_ratio).div(PRICE_PRECISION)
        );
        uint256 ton_amount = ton_dollar_value_d18.mul(PRICE_PRECISION).div(ton_price);

        // Need to adjust for decimals of collateral
        uint256 pho_amount_precision = pho_amount_post_fee.div(10 ** missing_decimals);
        uint256 collateral_dollar_value =
            pho_amount_precision.mul(global_collateral_ratio).div(PRICE_PRECISION);
        uint256 collateral_amount = collateral_dollar_value.mul(PRICE_PRECISION).div(col_price_usd);

        require(
            collateral_amount
                <= collateral_token.balanceOf(address(this)).sub(unclaimedPoolCollateral),
            "Not enough collateral in pool"
        );
        require(COLLATERAL_out_min <= collateral_amount, "Slippage limit reached [collateral]");
        require(TON_out_min <= ton_amount, "Slippage limit reached [TON]");

        redeemCollateralBalances[msg.sender] =
            redeemCollateralBalances[msg.sender].add(collateral_amount);
        unclaimedPoolCollateral = unclaimedPoolCollateral.add(collateral_amount);

        redeemTONBalances[msg.sender] = redeemTONBalances[msg.sender].add(ton_amount);
        unclaimedPoolTON = unclaimedPoolTON.add(ton_amount);

        lastRedeemed[msg.sender] = block.number;

        // Move all external functions to the end
        pho.pool_burn_from(msg.sender, pho_amount);
        ton.pool_mint(address(this), ton_amount);
    }

    // Redeem PHO for TON. 0% collateral-backed
    // function redeemAlgorithmicPHO(uint256 PHO_amount, uint256 TON_out_min) external notRedeemPaused {
    //     uint256 ton_price = priceOracle.getTONUSDPrice();
    //     uint256 global_collateral_ratio = pid.global_collateral_ratio();

    //     require(global_collateral_ratio == 0, "Collateral ratio must be 0");
    //     uint256 ton_dollar_value_d18 = PHO_amount;

    //     ton_dollar_value_d18 = (ton_dollar_value_d18.mul(uint(1e6).sub(redemption_fee))).div(PRICE_PRECISION); //apply fees

    //     uint256 ton_amount = ton_dollar_value_d18.mul(PRICE_PRECISION).div(ton_price);

    //     redeemTONBalances[msg.sender] = redeemTONBalances[msg.sender].add(ton_amount);
    //     unclaimedPoolTON = unclaimedPoolTON.add(ton_amount);

    //     lastRedeemed[msg.sender] = block.number;

    //     require(TON_out_min <= ton_amount, "Slippage limit reached");
    //     // Move all external functions to the end
    //     pho.pool_burn_from(msg.sender, PHO_amount);
    //     ton.pool_mint(address(this), ton_amount);
    // }

    function collectRedemption() external {
        require(
            (lastRedeemed[msg.sender].add(redemption_delay)) <= block.number,
            "Must wait for redemption_delay blocks before collecting redemption"
        );
        bool sendTON = false;
        bool sendCollateral = false;
        uint256 TONAmount = 0;
        uint256 CollateralAmount = 0;

        // Use Checks-Effects-Interactions pattern
        if (redeemTONBalances[msg.sender] > 0) {
            TONAmount = redeemTONBalances[msg.sender];
            redeemTONBalances[msg.sender] = 0;
            unclaimedPoolTON = unclaimedPoolTON.sub(TONAmount);

            sendTON = true;
        }

        if (redeemCollateralBalances[msg.sender] > 0) {
            CollateralAmount = redeemCollateralBalances[msg.sender];
            redeemCollateralBalances[msg.sender] = 0;
            unclaimedPoolCollateral = unclaimedPoolCollateral.sub(CollateralAmount);

            sendCollateral = true;
        }

        if (sendTON) {
            TransferHelper.safeTransfer(address(ton), msg.sender, TONAmount);
        }
        if (sendCollateral) {
            TransferHelper.safeTransfer(address(collateral_token), msg.sender, CollateralAmount);
        }
    }

    // When the protocol is recollateralizing, we need to give a discount of TON to hit the new CR target
    // Thus, if the target collateral ratio is higher than the actual value of collateral, minters get TON for adding collateral
    // This function simply rewards anyone that sends collateral to a pool with the same amount of TON + the bonus rate
    // Anyone can call this function to recollateralize the protocol and take the extra TON value from the bonus rate as an arb opportunity
    function recollateralizePHO(uint256 collateral_amount, uint256 TON_out_min) external {
        require(recollateralizePaused == false, "Recollateralize is paused");
        uint256 collateral_amount_d18 = collateral_amount * (10 ** missing_decimals);
        uint256 ton_price = priceOracle.getTONUSDPrice();
        uint256 pho_total_supply = pho.totalSupply();
        uint256 global_collateral_ratio = pid.global_collateral_ratio();
        uint256 global_collat_value = pid.globalCollateralValue();

        (uint256 collateral_units, uint256 amount_to_recollat) = PoolLibrary
            .calcRecollateralizePHOInner(
            collateral_amount_d18,
            getCollateralPrice(),
            global_collat_value,
            pho_total_supply,
            global_collateral_ratio
        );

        uint256 collateral_units_precision = collateral_units.div(10 ** missing_decimals);

        uint256 ton_paid_back =
            amount_to_recollat.mul(uint256(1e6).add(bonus_rate).sub(recollat_fee)).div(ton_price);

        require(TON_out_min <= ton_paid_back, "Slippage limit reached");
        TransferHelper.safeTransferFrom(
            address(collateral_token), msg.sender, address(this), collateral_units_precision
        );
        ton.pool_mint(msg.sender, ton_paid_back);
    }

    // Function can be called by an TON holder to have the protocol buy back TON with excess collateral value from a desired collateral pool
    // This can also happen if the collateral ratio > 1
    function buyBackTON(uint256 TON_amount, uint256 COLLATERAL_out_min) external {
        require(buyBackPaused == false, "Buyback is paused");
        uint256 ton_price = priceOracle.getTONUSDPrice();

        PoolLibrary.BuybackTON_Params memory input_params = PoolLibrary.BuybackTON_Params(
            availableExcessCollatDV(), ton_price, getCollateralPrice(), TON_amount
        );

        (uint256 collateral_equivalent_d18) =
            (PoolLibrary.calcBuyBackTON(input_params)).mul(uint256(1e6).sub(buyback_fee)).div(1e6);
        uint256 collateral_precision = collateral_equivalent_d18.div(10 ** missing_decimals);

        require(COLLATERAL_out_min <= collateral_precision, "Slippage limit reached");
        // Give the sender their desired collateral and burn the TON
        ton.pool_burn_from(msg.sender, TON_amount);
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
        if (collateralPricePaused == false) {
            pausedPrice = _new_price;
        } else {
            pausedPrice = 0;
        }
        collateralPricePaused = !collateralPricePaused;

        emit CollateralPriceToggled(collateralPricePaused);
    }

    // Combined into one function due to 24KiB contract memory limit
    function setPoolParameters(
        uint256 new_ceiling,
        uint256 new_bonus_rate,
        uint256 new_redemption_delay,
        uint256 new_mint_fee,
        uint256 new_redeem_fee,
        uint256 new_buyback_fee,
        uint256 new_recollat_fee
    )
        external
        onlyByOwnGov
    {
        pool_ceiling = new_ceiling;
        bonus_rate = new_bonus_rate;
        redemption_delay = new_redemption_delay;
        minting_fee = new_mint_fee;
        redemption_fee = new_redeem_fee;
        buyback_fee = new_buyback_fee;
        recollat_fee = new_recollat_fee;

        emit PoolParametersSet(
            new_ceiling,
            new_bonus_rate,
            new_redemption_delay,
            new_mint_fee,
            new_redeem_fee,
            new_buyback_fee,
            new_recollat_fee
            );
    }

    function setTimelock(address new_timelock) external onlyByOwnGov {
        timelock_address = new_timelock;

        emit TimelockSet(new_timelock);
    }

    /* ========== EVENTS ========== */

    event PoolParametersSet(
        uint256 new_ceiling,
        uint256 new_bonus_rate,
        uint256 new_redemption_delay,
        uint256 new_mint_fee,
        uint256 new_redeem_fee,
        uint256 new_buyback_fee,
        uint256 new_recollat_fee
    );
    event TimelockSet(address new_timelock);
    event MintingToggled(bool toggled);
    event RedeemingToggled(bool toggled);
    event RecollateralizeToggled(bool toggled);
    event BuybackToggled(bool toggled);
    event CollateralPriceToggled(bool toggled);
}
