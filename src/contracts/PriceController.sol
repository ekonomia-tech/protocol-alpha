// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../interfaces/IPHO.sol";
import "../interfaces/IPriceController.sol";
import "../oracle/DummyOracle.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/curve/ICurve.sol";
import "../interfaces/curve/ICurveFactory.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title PriceBalancer
/// @author Ekonomia: https://github.com/ekonomia-tech

contract PriceController is IPriceController, Ownable, AccessControl {
    address public controller_address;

    uint256 public priceBand;

    /// The price band in which the price is allowed to fluctuate and will not trigger the balancing process
    uint256 public gapFraction;

    /// represents the fraction of the gap to be bridged
    uint256 public cooldownPeriod;

    /// the colldown period between the kicks to the stabilizing mechanism
    uint256 public lastCooldownReset;

    IPHO public pho;
    DummyOracle public priceOracle;
    ICurve public dexPool;
    ICurveFactory public curveFactory;
    IERC20 public stabilizingToken;

    uint256 private constant PRICE_TARGET = 10 ** 6;
    uint256 private constant PRICE_PRECISION = 10 ** 18;
    uint256 private constant FRACTION_PRECISION = 10 ** 5;

    modifier onlyByOwnerGovernanceOrController() {
        require(
            msg.sender == owner() || msg.sender == controller_address || msg.sender == address(this),
            "Not the owner or controller"
        );
        _;
    }

    constructor(
        address _pho_address,
        address _oracle_address,
        address _dex_pool_address,
        address _stabilizing_token,
        address _curve_factory,
        address _controller_address,
        uint256 _cooldownPeriod,
        uint256 _priceBand,
        uint256 _gapFraction
    ) {
        pho = IPHO(_pho_address);
        priceOracle = DummyOracle(_oracle_address);
        dexPool = ICurve(_dex_pool_address);
        stabilizingToken = IERC20(_stabilizing_token);
        curveFactory = ICurveFactory(_curve_factory);

        controller_address = _controller_address;

        cooldownPeriod = _cooldownPeriod;
        priceBand = _priceBand;
        gapFraction = _gapFraction;

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /// @notice this function checks the price on the market and stablezes it according to the gap that has to be bridged.
    /// @return stabilized a bool represnting if a stabilization process was executed or not
    /// The function will not bridge the whole gap, but a certain part of it to make sure the bridging will not oversell/overbuy.
    function stabilize() public returns (bool stabilized) {
        require(block.timestamp - lastCooldownReset > cooldownPeriod, "cooldown not satisfied");

        /// Get the current price of PHO from the price oracle abstraction
        uint256 phoPrice = priceOracle.getPHOUSDPrice();

        /// Check if the current price is in the price band, received price gap and trend
        (bool inBand, uint256 priceGap, bool trend) = checkPriceBand(phoPrice);

        /// if the PHO price i exactly 10**18 or the price iis within the price band, reset cooldown and exit;
        if (phoPrice == PRICE_TARGET || inBand) {
            lastCooldownReset = block.timestamp;
            stabilized = false;
            return stabilized;
        }

        /// Calculate the amount of tokens need to b exchanged
        uint256 tokenAmount = calculateGapInToken(phoPrice, priceGap, trend);

        uint256 amountReceived;
        address tokenReceived;

        if (trend) {
            /// if the market price is >1 then mint pho and exchange pho for bpToken
            pho.pool_mint(address(this), tokenAmount);
            (tokenReceived, amountReceived) = exchangeTokens(true, tokenAmount);
            emit TokensExchanged(
                address(dexPool), address(pho), tokenAmount, tokenReceived, amountReceived
                );
        } else {
            (tokenReceived, amountReceived) = exchangeTokens(false, tokenAmount);
            emit TokensExchanged(
                address(dexPool), address(stabilizingToken), tokenAmount, address(pho), amountReceived
                );

            pho.approve(address(this), amountReceived);
            pho.pool_burn_from(address(this), amountReceived);
        }

        lastCooldownReset = block.timestamp;
        stabilized = true;
    }

    /// @notice Checks the if the current price is whithin the permitted price band and returns the priceGap from price traget and the trend
    /// @param _current_price the current price of pho
    /// @return inBand returns whteher the price is in the price band or not
    /// @return priceGap The gap between the price target and the current price
    /// @return trend over peg = true; under peg = false

    function checkPriceBand(uint256 _current_price)
        public
        view
        returns (bool inBand, uint256 priceGap, bool trend)
    {
        if (_current_price < PRICE_TARGET) {
            priceGap = PRICE_TARGET - _current_price;
            trend = false;
        } else {
            priceGap = _current_price - PRICE_TARGET;
            trend = true;
        }
        inBand = priceGap < priceBand;
    }

    /// @notice This funtion takes in the gap between the market price and the target price, fractionalizing it according to
    /// gapFraction parameter and converting it into amount of tokens to exchange.
    /// @param _price the PHO market price
    /// @param _priceGap the current price gap of PHO between the market price and the target price
    /// @param _trend market price > 1 = true; market price < 1 = false

    function calculateGapInToken(uint256 _price, uint256 _priceGap, bool _trend)
        public
        view
        returns (uint256 amount)
    {
        uint256 precentageChange;
        uint256 actualTargetPrice;
        uint256 totalSupply = pho.totalSupply();

        // Calculate the fractional gap to mitigate
        uint256 gapToMitigate = (_priceGap * gapFraction) / FRACTION_PRECISION;

        if (_trend) {
            actualTargetPrice = _price - gapToMitigate;
            precentageChange = (_price - actualTargetPrice) * FRACTION_PRECISION / _price;
        } else {
            actualTargetPrice = _price + gapToMitigate;
            precentageChange = (actualTargetPrice - _price) * FRACTION_PRECISION / _price;
        }

        amount = (totalSupply * precentageChange) / FRACTION_PRECISION;
    }

    /// @notice abstracts the token exchange from the curve pool
    /// @param _phoIn deteremines wether the sent token is pho or not
    /// @param _amountIn the amount of the token being sent
    /// @return tokenOut the received token address
    /// @return tokensReceived the amount fo of tokens received back from the exchange

    function exchangeTokens(bool _phoIn, uint256 _amountIn)
        public
        onlyByOwnerGovernanceOrController
        returns (address tokenOut, uint256 tokensReceived)
    {
        require(_amountIn > 0, "amount cannot be 0");

        uint256 minOut;

        if (_phoIn) {
            address basePool = curveFactory.get_base_pool(address(dexPool));
            address basePoolLP = ICurve(basePool).lp_token();
            (int128 phoIndex, int128 basePoolIndex,) =
                curveFactory.get_coin_indices(address(dexPool), address(pho), address(basePoolLP));

            minOut = dexPool.get_dy(phoIndex, basePoolIndex, _amountIn) * 99 / 100;
            pho.approve(address(dexPool), _amountIn);
            tokensReceived = dexPool.exchange(phoIndex, basePoolIndex, _amountIn, minOut);
            tokenOut = basePoolLP;
        } else {
            uint256 stabilizingTokenDecimals = ERC20(address(stabilizingToken)).decimals();

            /// Make the function generic and able to receive any type of stabilizing token
            if (stabilizingTokenDecimals != 18) {
                _amountIn = _amountIn / (10 ** (18 - stabilizingTokenDecimals));
            }

            uint256 stabilizingTokenBalance = stabilizingToken.balanceOf(address(this));
            require(
                stabilizingTokenBalance > _amountIn, "Stabilizing token does not have enough balance"
            );
            stabilizingToken.approve(address(dexPool), _amountIn);

            (int128 stabilizingTokenIndex, int128 phoIndex,) =
                curveFactory.get_coin_indices(address(dexPool), address(stabilizingToken), address(pho));

            minOut =
                dexPool.get_dy_underlying(stabilizingTokenIndex, phoIndex, _amountIn) * 99 / 100;
            tokensReceived =
                dexPool.exchange_underlying(stabilizingTokenIndex, phoIndex, _amountIn, minOut);
            tokenOut = address(stabilizingToken);
        }
    }

    function setOracleAddress(address _oracle_Aaddress) public onlyByOwnerGovernanceOrController {
        require(_oracle_Aaddress != address(0), "Zero address detected");
        priceOracle = DummyOracle(_oracle_Aaddress);
        emit OracleAddressSet(address(priceOracle));
    }

    function setController(address _controller_address)
        external
        onlyByOwnerGovernanceOrController
    {
        require(_controller_address != address(0), "Zero address detected");
        controller_address = _controller_address;
        emit ControllerSet(_controller_address);
    }

    function setCooldownPeriod(uint256 _cooldown_period) public onlyByOwnerGovernanceOrController {
        require(_cooldown_period >= 3600, "cooldown period cannot be shorter then 1 hour");
        uint256 previousCooldownPeriod = cooldownPeriod;
        cooldownPeriod = _cooldown_period;
        emit CooldownPeriodUpdated(previousCooldownPeriod, cooldownPeriod);
    }

    function setPriceBand(uint256 _price_band) public onlyByOwnerGovernanceOrController {
        require(_price_band > 0, "price band cannot be 0");
        uint256 previousPriceBand = priceBand;
        priceBand = _price_band;
        emit PriceBandUpdated(previousPriceBand, priceBand);
    }

    function setGapFraction(uint256 _gap_fraction) public onlyByOwnerGovernanceOrController {
        require(
            _gap_fraction > 0 && _gap_fraction < FRACTION_PRECISION,
            "value can only be between 0 to 100000"
        );
        uint256 previousGapFraction = gapFraction;
        gapFraction = _gap_fraction;
        emit GapFractionUpdated(previousGapFraction, gapFraction);
    }

    function setDexPool(address _dex_pool_address) public onlyByOwnerGovernanceOrController {
        require(_dex_pool_address != address(0), "zero address detected");
        dexPool = ICurve(_dex_pool_address);
        emit DexPoolUpdated(_dex_pool_address);
    }

    function setStabilizingToken(address _stabilizing_token)
        public
        onlyByOwnerGovernanceOrController
    {
        require(_stabilizing_token != address(0), "zero address detected");
        stabilizingToken = IERC20(_stabilizing_token);
        emit StabilizingTokenUpdated(_stabilizing_token);
    }
}
