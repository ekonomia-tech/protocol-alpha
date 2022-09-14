// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../interfaces/IPHO.sol";
import "../interfaces/IPriceController.sol";
import "../interfaces/ITeller.sol";
import "../oracle/DummyOracle.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/curve/ICurvePool.sol";
import "../interfaces/curve/ICurveFactory.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title PriceController
/// @author Ekonomia: https://github.com/ekonomia-tech

contract PriceController is IPriceController, Ownable, AccessControl {
    address public controllerAddress;

    /// The price band in which the price is allowed to fluctuate and will not trigger the balancing process
    uint256 public priceBand;

    /// represents the fraction of the gap to be bridged
    uint256 public gapFraction;

    /// the cooldown period between the kicks to the stabilizing mechanism
    uint256 public cooldownPeriod;

    /// the last timestamp the stabilize() function has ran
    uint256 public lastCooldownReset;

    /// representing the maximum slippage percentage in 10 ** 6;
    uint256 public maxSlippage;

    uint256 stabilizingTokenDecimals;

    IPHO public pho;
    ITeller public teller;
    DummyOracle public priceOracle;
    ICurvePool public dexPool;
    ICurveFactory public curveFactory;
    IERC20 public stabilizingToken;

    uint256 private constant PRICE_TARGET = 10 ** 6;
    uint256 private constant PRICE_PRECISION = 10 ** 18;
    uint256 private constant FRACTION_PRECISION = 10 ** 5;
    uint256 private constant SLIPPAGE_PRECISION = 10 ** 6;

    modifier onlyByOwnerGovernanceOrController() {
        require(
            msg.sender == owner() || msg.sender == controllerAddress || msg.sender == address(this),
            "Price Controller: not the owner or controller"
        );
        _;
    }

    constructor(
        address _pho_address,
        address _teller_address,
        address _oracle_address,
        address _dex_pool_address,
        address _stabilizing_token,
        address _curve_factory,
        address _controller_address,
        uint256 _cooldownPeriod,
        uint256 _priceBand,
        uint256 _gapFraction,
        uint256 _max_slippage
    ) {
        require(_pho_address != address(0), "Price Controller: zero address detected");
        require(_teller_address != address(0), "Price Controller: zero address detected");
        require(_oracle_address != address(0), "Price Controller: zero address detected");
        require(_dex_pool_address != address(0), "Price Controller: zero address detected");
        require(_stabilizing_token != address(0), "Price Controller: zero address detected");
        require(_curve_factory != address(0), "Price Controller: zero address detected");
        require(_controller_address != address(0), "Price Controller: zero address detected");
        require(
            _cooldownPeriod >= 3600,
            "Price Controller: cooldown period cannot be shorter then 1 hour"
        );
        require(
            _priceBand > 0 && _priceBand < FRACTION_PRECISION,
            "Price Controller: value can only be between 0 to 100000"
        );
        require(
            _gapFraction > 0 && _gapFraction < FRACTION_PRECISION,
            "Price Controller: value can only be between 0 to 100000"
        );
        require(
            _max_slippage > 0 && _max_slippage < FRACTION_PRECISION,
            "Price Controller: value can only be between 0 to 100000"
        );

        pho = IPHO(_pho_address);
        teller = ITeller(_teller_address);
        priceOracle = DummyOracle(_oracle_address);
        dexPool = ICurvePool(_dex_pool_address);
        stabilizingToken = IERC20(_stabilizing_token);
        stabilizingTokenDecimals = IERC20Metadata(_stabilizing_token).decimals();
        curveFactory = ICurveFactory(_curve_factory);

        controllerAddress = _controller_address;

        cooldownPeriod = _cooldownPeriod;
        priceBand = _priceBand;
        gapFraction = _gapFraction;
        maxSlippage = _max_slippage;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /// @notice this function checks the price on the market and stabilizes it according to the gap that has to be bridged.
    /// @return bool representing if a stabilization process was executed or not
    /// The function will not bridge the whole gap, but a certain part of it to make sure the bridging will not oversell/overbuy.
    function stabilize() external returns (bool) {
        require(
            block.timestamp - lastCooldownReset > cooldownPeriod,
            "Price Controller: cooldown not satisfied"
        );

        // Get the current price of PHO from the price oracle abstraction
        uint256 phoPrice = priceOracle.getPHOUSDPrice();

        // Check if the current price is in the price band, received price gap and trend
        (bool inBand, uint256 priceGap, bool trend) = checkPriceBand(phoPrice);

        // if the $PHO price is exactly 10**18 or the price is within the price band, reset cooldown and exit;
        if (inBand) {
            lastCooldownReset = block.timestamp;
            return false;
        }

        // Calculate the amount of tokens need to b exchanged
        uint256 tokenAmount = calculateGapInToken(phoPrice, priceGap);

        uint256 amountReceived;

        if (trend) {
            // if the market price is >1 then mint pho and exchange pho for bpToken
            teller.mintPHO(address(this), tokenAmount);
            amountReceived = exchangeTokens(true, tokenAmount);
        } else {
            amountReceived = exchangeTokens(false, tokenAmount);
            pho.approve(address(this), amountReceived);
            pho.burn(address(this), amountReceived);
        }

        lastCooldownReset = block.timestamp;
        return true;
    }

    /// @notice Checks the if the current price is within the permitted price band and returns the priceGap from price target and the trend
    /// @param current_price the current price of pho
    /// @return inBand returns whether the price is in the price band or not
    /// @return priceGap The gap between the price target and the current price
    /// @return trend over peg = true; under peg = false
    function checkPriceBand(uint256 current_price) public view returns (bool, uint256, bool) {
        uint256 priceGap;
        bool inBand;
        bool trend;

        if (current_price < PRICE_TARGET) {
            priceGap = PRICE_TARGET - current_price;
            trend = false;
        } else {
            priceGap = current_price - PRICE_TARGET;
            trend = true;
        }
        inBand = priceGap < priceBand;
        return (inBand, priceGap, trend);
    }

    /// @notice This function takes in the gap between the market price and the target price, fractionalizing it according to gapFraction parameter and converting it into amount of tokens to exchange.
    /// @param price the PHO market price
    /// @param priceGap the current price gap of PHO between the market price and the target price

    function calculateGapInToken(uint256 price, uint256 priceGap) public view returns (uint256) {
        uint256 totalSupply = pho.totalSupply();

        uint256 percentageChange = priceGap * gapFraction / price;

        return (totalSupply * percentageChange) / FRACTION_PRECISION;
    }

    /// @notice abstracts the token exchange from the curve pool
    /// @param phoIn determines wether the sent token is pho or not
    /// @param amountIn the amount of the token being sent
    /// @return tokensReceived the amount of tokens received back from the exchange
    function exchangeTokens(bool phoIn, uint256 amountIn)
        public
        onlyByOwnerGovernanceOrController
        returns (uint256)
    {
        require(amountIn > 0, "Price Controller: amount cannot be 0");

        uint256 minOut;
        uint256 tokensReceived;

        if (phoIn) {
            address basePool = curveFactory.get_base_pool(address(dexPool));
            address basePoolLP = ICurvePool(basePool).lp_token();
            (int128 phoIndex, int128 basePoolIndex,) =
                curveFactory.get_coin_indices(address(dexPool), address(pho), address(basePoolLP));

            minOut =
                dexPool.get_dy(phoIndex, basePoolIndex, amountIn) * maxSlippage / SLIPPAGE_PRECISION;
            pho.approve(address(dexPool), amountIn);
            tokensReceived = dexPool.exchange(phoIndex, basePoolIndex, amountIn, minOut);

            emit TokensExchanged(
                address(dexPool), address(pho), amountIn, basePoolLP, tokensReceived
                );
        } else {
            // Make the function generic and able to receive any type of stabilizing token
            if (stabilizingTokenDecimals != 18) {
                amountIn = amountIn / (10 ** (18 - stabilizingTokenDecimals));
            }

            uint256 stabilizingTokenBalance = stabilizingToken.balanceOf(address(this));
            require(
                stabilizingTokenBalance > amountIn,
                "Price Controller: stabilizing token does not have enough balance"
            );
            stabilizingToken.approve(address(dexPool), amountIn);

            // To get the expected tokens out, we need to get the index of the underlying token we wish to swap
            (int128 stabilizingTokenIndex, int128 phoIndex,) = curveFactory.get_coin_indices(
                address(dexPool), address(stabilizingToken), address(pho)
            );

            // getting the expected $PHO from the swap by calling get_dy_underlying with the underlying token
            minOut = dexPool.get_dy_underlying(stabilizingTokenIndex, phoIndex, amountIn)
                * maxSlippage / SLIPPAGE_PRECISION;
            // exchange the underlying token of the base pool in the metapool for $PHO
            tokensReceived =
                dexPool.exchange_underlying(stabilizingTokenIndex, phoIndex, amountIn, minOut);

            emit TokensExchanged(
                address(dexPool), address(stabilizingToken), amountIn, address(pho), tokensReceived
                );
        }
        return tokensReceived;
    }

    /// @notice set the oracle address for this contract
    function setOracleAddress(address newOracleAddress)
        external
        onlyByOwnerGovernanceOrController
    {
        require(newOracleAddress != address(0), "Price Controller: zero address detected");
        require(newOracleAddress != address(priceOracle), "Price Controller: same address detected");
        priceOracle = DummyOracle(newOracleAddress);
        emit OracleAddressSet(address(priceOracle));
    }

    /// @notice set the controller address
    function setController(address newControllerAddress)
        external
        onlyByOwnerGovernanceOrController
    {
        require(newControllerAddress != address(0), "Price Controller: zero address detected");
        require(
            newControllerAddress != controllerAddress, "Price Controller: same address detected"
        );
        controllerAddress = newControllerAddress;
        emit ControllerSet(newControllerAddress);
    }

    /// @notice set the cooldown period between stabilize() runs
    function setCooldownPeriod(uint256 newCooldownPeriod)
        external
        onlyByOwnerGovernanceOrController
    {
        require(
            newCooldownPeriod >= 3600,
            "Price Controller: cooldown period cannot be shorter then 1 hour"
        );
        require(newCooldownPeriod != cooldownPeriod, "Price Controller: same value detected");
        cooldownPeriod = newCooldownPeriod;
        emit CooldownPeriodUpdated(cooldownPeriod);
    }

    /// @notice set the price band in which stabilize will not perform any actions
    function setPriceBand(uint256 newPriceBand) external onlyByOwnerGovernanceOrController {
        require(newPriceBand > 0, "Price Controller: price band cannot be 0");
        require(newPriceBand != priceBand, "Price Controller: same value detected");
        priceBand = newPriceBand;
        emit PriceBandUpdated(priceBand);
    }

    ///@notice set the fraction from the gap to be mitigated with the market
    function setGapFraction(uint256 newGapFraction) external onlyByOwnerGovernanceOrController {
        require(
            newGapFraction > 0 && newGapFraction < FRACTION_PRECISION,
            "Price Controller: value can only be between 0 to 100000"
        );
        require(newGapFraction != gapFraction, "Price Controller: same value detected");
        gapFraction = newGapFraction;
        emit GapFractionUpdated(gapFraction);
    }

    /// @notice set the dex pool address that this contract interacts with
    function setDexPool(address newDexPool) external onlyByOwnerGovernanceOrController {
        require(newDexPool != address(0), "Price Controller: zero address detected");
        require(
            curveFactory.is_meta(newDexPool),
            "Price Controller: address does not point to a metapool"
        );
        require(newDexPool != address(dexPool), "Price Controller: same address detected");

        address[8] memory underlyingCoins = curveFactory.get_underlying_coins(newDexPool);
        bool isPhoPresent = false;
        for (uint256 i = 0; i < underlyingCoins.length; i++) {
            if (underlyingCoins[i] == address(pho)) {
                isPhoPresent = true;
                break;
            }
        }
        require(isPhoPresent, "Price Controller: $PHO is not present in the metapool");

        dexPool = ICurvePool(newDexPool);
        emit DexPoolUpdated(newDexPool);
    }

    /// @notice set the stabilizing token address - has to be and underlying token of the base pool
    function setStabilizingToken(address newStabilizingToken)
        external
        onlyByOwnerGovernanceOrController
    {
        require(newStabilizingToken != address(0), "Price Controller: zero address detected");
        require(
            newStabilizingToken != address(stabilizingToken),
            "Price Controller: same address detected"
        );
        address[8] memory underlyingCoins = curveFactory.get_underlying_coins(address(dexPool));
        bool isTokenUnderlying = false;
        for (uint256 i = 0; i < underlyingCoins.length; i++) {
            if (underlyingCoins[i] == newStabilizingToken) {
                isTokenUnderlying = true;
                break;
            }
        }
        require(isTokenUnderlying, "Price Controller: token is not an underlying in the base pool");

        stabilizingToken = IERC20(newStabilizingToken);
        stabilizingTokenDecimals = IERC20Metadata(newStabilizingToken).decimals();
        emit StabilizingTokenUpdated(newStabilizingToken);
    }

    ///@notice set the maximum slippage allowed in exchanges with the dex pool
    function setMaxSlippage(uint256 newMaxSlippage) external onlyByOwnerGovernanceOrController {
        require(
            newMaxSlippage > 0 && newMaxSlippage < FRACTION_PRECISION,
            "Price Controller: value can only be between 0 to 100000"
        );
        require(newMaxSlippage != maxSlippage, "Price Controller: same value detected");
        maxSlippage = newMaxSlippage;
        emit MaxSlippageUpdated(maxSlippage);
    }
}
