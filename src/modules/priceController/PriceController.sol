// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@external/curve/ICurvePool.sol";
import "@external/curve/ICurveFactory.sol";
import "@protocol/contracts/PHO.sol";
import "@protocol/interfaces/IModuleManager.sol";
import "@modules/priceController/IPriceController.sol";
import "@oracle/DummyOracle.sol";

/// @title PriceController
/// @author Ekonomia: https://github.com/ekonomia-tech

contract PriceController is IPriceController, Ownable {
    /// The price band in which the price is allowed to fluctuate and will not trigger the balancing process
    uint256 public immutable priceBand;

    /// represents the fraction of the gap to be bridged
    uint256 public priceMitigationPercentage;

    /// the cooldown period between the kicks to the stabilizing mechanism
    uint256 public cooldownPeriod;

    /// the last timestamp the stabilize() function has ran
    uint256 public lastCooldownReset;

    /// representing the maximum slippage percentage in 10 ** 6;
    uint256 public maxSlippage;

    PHO public pho;
    DummyOracle public priceOracle;
    ICurvePool public dexPool;
    ICurveFactory public curveFactory = ICurveFactory(0xB9fC157394Af804a3578134A6585C0dc9cc990d4);
    IERC20 public usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IModuleManager public moduleManager;
    address public kernel;

    uint256 private constant PRICE_TARGET = 10 ** 6;
    uint256 private constant PRICE_PRECISION = 10 ** 18;
    uint256 private constant PERCENTAGE_PRECISION = 10 ** 5;

    constructor(
        address _pho_address,
        address _module_manager,
        address _kernel,
        address _oracle_address,
        address _dex_pool_address,
        uint256 _cooldownPeriod,
        uint256 _priceBand,
        uint256 _priceMitigationPercentage,
        uint256 _max_slippage
    ) {
        if (
            _pho_address == address(0) || _module_manager == address(0) || _kernel == address(0)
                || _oracle_address == address(0) || _dex_pool_address == address(0)
        ) revert ZeroAddress();

        if (_cooldownPeriod < 3600) revert CooldownPeriodAtLeastOneHour();
        if (
            (_priceBand == 0 || _priceBand > 100000)
                || (_priceMitigationPercentage == 0 || _priceMitigationPercentage > 100000)
                || (_max_slippage == 0 || _max_slippage > 100000)
        ) {
            revert ValueNotInRange();
        }

        pho = PHO(_pho_address);
        moduleManager = IModuleManager(_module_manager);
        kernel = _kernel;
        priceOracle = DummyOracle(_oracle_address);
        dexPool = ICurvePool(_dex_pool_address);

        cooldownPeriod = _cooldownPeriod;
        priceBand = _priceBand;
        priceMitigationPercentage = _priceMitigationPercentage;
        maxSlippage = _max_slippage;
    }

    /// @notice this function checks the price on the market and stabilizes it according to the gap that has to be bridged.
    /// @return bool representing if a stabilization process was executed or not
    /// The function will not bridge the whole gap, but a certain part of it to make sure the bridging will not oversell/overbuy.
    function stabilize() external returns (bool) {
        if (block.timestamp - lastCooldownReset <= cooldownPeriod) revert CooldownNotSatisfied();

        // Get the current price of PHO from the price oracle abstraction
        uint256 phoPrice = priceOracle.getPHOUSDPrice();

        // Check if the current price is in the price band, received price gap and trend
        (uint256 diff, bool over) = checkPriceBand(phoPrice);

        // if the $PHO price is exactly 10**18 or the price is within the price band, reset cooldown and exit;
        if (diff < priceBand) {
            lastCooldownReset = block.timestamp;
            return false;
        }

        // Calculate the amount of tokens need to be exchanged
        uint256 tokenAmount = marketToTargetDiff(phoPrice, diff);

        if (over) {
            _mintAndSellPHO(tokenAmount);
        } else {
            _buyAndBurnPHO(tokenAmount / (10 ** 12));
        }

        lastCooldownReset = block.timestamp;
        return true;
    }

    /// @notice Checks the if the current price is within the permitted price band and returns the priceGap from price target and the trend
    /// @param current_price the current price of pho
    /// @return diff The gap between the price target and the current price
    /// @return over over peg = true; under peg = false
    function checkPriceBand(uint256 current_price) public pure returns (uint256, bool) {
        if (current_price < PRICE_TARGET || current_price == PRICE_TARGET) {
            return (PRICE_TARGET - current_price, false);
        }
        return (current_price - PRICE_TARGET, true);
    }

    /// @notice This function takes in the gap between the market price and the target price, fractionalizing it according to priceMitigationPercentage parameter and converting it into amount of tokens to exchange.
    /// @param price the PHO market price
    /// @param diff the current price gap of PHO between the market price and the target price

    function marketToTargetDiff(uint256 price, uint256 diff) public view returns (uint256) {
        uint256 totalSupply = pho.totalSupply();
        uint256 percentageChange = diff * priceMitigationPercentage / price;
        return (totalSupply * percentageChange) / PERCENTAGE_PRECISION;
    }

    /// @notice mints $PHO and sells it to the market in return for collateral
    /// @param phoAmount the amount of $PHO to mint and exchange
    function _mintAndSellPHO(uint256 phoAmount) private returns (uint256) {
        if (phoAmount == 0) revert ZeroValue();

        moduleManager.mintPHO(address(this), phoAmount);
        pho.approve(address(dexPool), phoAmount);

        address basePool = curveFactory.get_base_pool(address(dexPool));
        address basePoolLP = ICurvePool(basePool).lp_token();
        (int128 phoIndex, int128 basePoolIndex,) =
            curveFactory.get_coin_indices(address(dexPool), address(pho), address(basePoolLP));

        uint256 minOut =
            dexPool.get_dy(phoIndex, basePoolIndex, phoAmount) * maxSlippage / PERCENTAGE_PRECISION;
        uint256 tokensReceived = dexPool.exchange(phoIndex, basePoolIndex, phoAmount, minOut);

        emit TokensExchanged(address(dexPool), address(pho), phoAmount, basePoolLP, tokensReceived);

        return tokensReceived;
    }

    /// @notice buys $PHO back from the market and burns it
    /// @param collateralAmount the amount of collateral to exchange for $PHO
    function _buyAndBurnPHO(uint256 collateralAmount) private returns (uint256) {
        if (collateralAmount == 0) revert ZeroValue();

        if (usdc.balanceOf(address(this)) < collateralAmount) {
            revert NotEnoughBalanceInStabilizer();
        }

        usdc.approve(address(dexPool), collateralAmount);

        // To get the expected tokens out, we need to get the index of the underlying token we wish to swap
        (int128 usdcIndex, int128 phoIndex,) =
            curveFactory.get_coin_indices(address(dexPool), address(usdc), address(pho));

        // getting the expected $PHO from the swap by calling get_dy_underlying with the underlying token
        uint256 minOut = dexPool.get_dy_underlying(usdcIndex, phoIndex, collateralAmount)
            * maxSlippage / PERCENTAGE_PRECISION;
        // exchange the underlying token of the base pool in the metapool for $PHO
        uint256 tokensReceived =
            dexPool.exchange_underlying(usdcIndex, phoIndex, collateralAmount, minOut);

        emit TokensExchanged(
            address(dexPool), address(usdc), collateralAmount, address(pho), tokensReceived
            );

        pho.approve(address(kernel), tokensReceived);
        moduleManager.burnPHO(address(this), tokensReceived);

        return tokensReceived;
    }

    /// @notice set the oracle address for this contract
    function setOracleAddress(address newOracleAddress) external onlyOwner {
        if (newOracleAddress == address(0)) revert ZeroAddress();
        if (newOracleAddress == address(priceOracle)) revert SameAddress();
        priceOracle = DummyOracle(newOracleAddress);
        emit OracleAddressSet(address(priceOracle));
    }

    /// @notice set the cooldown period between stabilize() runs
    function setCooldownPeriod(uint256 newCooldownPeriod) external onlyOwner {
        if (newCooldownPeriod < 3600) revert CooldownPeriodAtLeastOneHour();
        if (newCooldownPeriod == cooldownPeriod) revert SameValue();
        cooldownPeriod = newCooldownPeriod;
        emit CooldownPeriodUpdated(cooldownPeriod);
    }

    ///@notice set the fraction from the gap to be mitigated with the market
    function setPriceMitigationPercentage(uint256 newPriceMitigationPercentage)
        external
        onlyOwner
    {
        if (
            newPriceMitigationPercentage == 0 || newPriceMitigationPercentage > PERCENTAGE_PRECISION
        ) revert ValueNotInRange();
        if (newPriceMitigationPercentage == priceMitigationPercentage) revert SameValue();
        priceMitigationPercentage = newPriceMitigationPercentage;
        emit PriceMitigationPercentageUpdated(priceMitigationPercentage);
    }

    ///@notice set the maximum slippage allowed in exchanges with the dex pool
    function setMaxSlippage(uint256 newMaxSlippage) external onlyOwner {
        if (newMaxSlippage == 0 || newMaxSlippage > PERCENTAGE_PRECISION) revert ValueNotInRange();
        if (newMaxSlippage == maxSlippage) revert SameValue();
        maxSlippage = newMaxSlippage;
        emit MaxSlippageUpdated(maxSlippage);
    }

    function buyAndBurnPHO(uint256 collateralAmount) public onlyOwner returns (uint256) {
        return _buyAndBurnPHO(collateralAmount);
    }

    function mintAndSellPHO(uint256 phoAmount) public onlyOwner returns (uint256) {
        return _mintAndSellPHO(phoAmount);
    }
}
