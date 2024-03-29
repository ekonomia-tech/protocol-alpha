// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@protocol/interfaces/IPHO.sol";
import "@protocol/interfaces/IModuleManager.sol";
import "@external/curve/ICurvePool.sol";
import "@oracle/IPriceOracle.sol";

/// @title FraxBP Init module
/// @author Ekonomia: https://github.com/ekonomia-tech
/// @notice Accepts FRAX & USDC
contract FraxBPInitModule is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20Metadata;

    /// Errors
    error ZeroAddressDetected();
    error CannotDepositAfterSaleEnded();
    error OnlyModuleManager();
    error CannotDepositZero();
    error InvalidTimeWindows();
    error CannotRedeemBeforeRedemptionStart();
    error CannotRedeemZero();

    /// Events
    event Deposited(address indexed depositor, uint256 fraxBPLpAmount, uint256 phoAmount);
    event Redeemed(address indexed redeemer, uint256 redeemAmount);

    /// State vars
    IModuleManager public moduleManager;
    IERC20Metadata public frax = IERC20Metadata(0x853d955aCEf822Db058eb8505911ED77F175b99e);
    IERC20Metadata public usdc = IERC20Metadata(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20Metadata public fraxBPLp = IERC20Metadata(0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC);
    ICurvePool public fraxBPPool = ICurvePool(0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2);
    ICurvePool public fraxBPPHOMetapool;
    //IERC20Metadata public fraxBPPHOLp;
    IPriceOracle public priceOracle;
    uint256 private constant USDC_SCALE = 10 ** 12;
    uint256 public constant PRICE_PRECISION = 10 ** 18;
    uint256 public saleEndDate; // when sale ends
    uint256 public redemptionStartDate; // when redemptions are available
    IPHO public pho;

    mapping(address => uint256) public metapoolBalance;

    modifier onlyModuleManager() {
        if (msg.sender != address(moduleManager)) revert OnlyModuleManager();
        _;
    }

    /// Constructor
    constructor(
        address _moduleManager,
        address _fraxBPPHOMetapool,
        address _pho,
        address _priceOracle,
        uint256 _saleEndDate,
        uint256 _redemptionStartDate
    ) {
        if (
            _moduleManager == address(0) || _fraxBPPHOMetapool == address(0) || _pho == address(0)
                || _priceOracle == address(0)
        ) {
            revert ZeroAddressDetected();
        }
        if (_saleEndDate <= block.timestamp || _redemptionStartDate <= _saleEndDate) {
            revert InvalidTimeWindows();
        }
        moduleManager = IModuleManager(_moduleManager);
        fraxBPPHOMetapool = ICurvePool(_fraxBPPHOMetapool);
        pho = IPHO(_pho);
        priceOracle = IPriceOracle(_priceOracle);
        saleEndDate = _saleEndDate;
        redemptionStartDate = _redemptionStartDate;

        usdc.approve(address(fraxBPPool), type(uint256).max);
        frax.approve(address(fraxBPPool), type(uint256).max);
    }

    /// @notice Helper for user depositing both FRAX and USDC
    /// @param usdcAmount USDC deposit amount
    /// @param fraxAmount FRAX deposit amount
    function depositHelper(uint256 usdcAmount, uint256 fraxAmount) external nonReentrant {
        if (block.timestamp > saleEndDate) {
            revert CannotDepositAfterSaleEnded();
        }
        uint256 totalAmount = usdcAmount * USDC_SCALE + fraxAmount;
        if (totalAmount == 0) {
            revert CannotDepositZero();
        }

        // transfer USDC and FRAX from caller
        if (usdcAmount != 0) {
            usdc.safeTransferFrom(msg.sender, address(this), usdcAmount);
        }
        if (fraxAmount != 0) {
            frax.safeTransferFrom(msg.sender, address(this), fraxAmount);
        }

        // convert to FraxBP LP here
        uint256 fraxBPLpBalanceBefore = fraxBPLp.balanceOf(address(this));
        uint256[2] memory fraxBPmetaLiquidity;
        fraxBPmetaLiquidity[0] = fraxAmount; // frax
        fraxBPmetaLiquidity[1] = usdcAmount; // usdc

        fraxBPPool.add_liquidity(fraxBPmetaLiquidity, 0);
        uint256 fraxBPLpBalanceAfter = fraxBPLp.balanceOf(address(this));

        // call _depositFor() for user based on FraxBP LP received
        uint256 fraxBPLpAmount = fraxBPLpBalanceAfter - fraxBPLpBalanceBefore;
        _depositFor(msg.sender, fraxBPLpAmount);
    }

    /// @notice Helper function for deposits in FraxBP LP token for user
    /// @param depositor Depositor
    /// @param amount Amount in FraxBP LP
    function _depositFor(address depositor, uint256 amount) private {
        uint256 usdPerFraxBP = getUSDPerFraxBP();
        uint256 phoAmount = (usdPerFraxBP * amount) / 10 ** 18;

        moduleManager.mintPHO(address(this), phoAmount);
        uint256 fraxBPPHOLpBalance = _addFraxBPPHOLiquidity(amount, phoAmount);

        metapoolBalance[depositor] += fraxBPPHOLpBalance;
        emit Deposited(depositor, amount, phoAmount);
    }

    /// @notice Places deposits in FraxBP LP token for user
    /// @param depositor Depositor
    /// @param amount Amount in FraxBP LP
    function depositFor(address depositor, uint256 amount) public {
        if (block.timestamp > saleEndDate) {
            revert CannotDepositAfterSaleEnded();
        }
        if (amount == 0) {
            revert CannotDepositZero();
        }
        fraxBPLp.safeTransferFrom(depositor, address(this), amount);
        _depositFor(depositor, amount);
    }

    /// @notice Accept deposits in FraxBP LP token
    /// @param amount Amount in FraxBP LP
    function deposit(uint256 amount) external nonReentrant {
        depositFor(msg.sender, amount);
    }

    /// @notice Adds FraxBP LP and PHO to FraxBP/PHO pool
    function _addFraxBPPHOLiquidity(uint256 fraxBPLPAmount, uint256 phoAmount)
        internal
        returns (uint256)
    {
        //uint256 fraxBPLPAmount = fraxBPLp.balanceOf(address(this));
        //uint256 phoAmount = pho.balanceOf(address(this));

        uint256 fraxBPPHOLpBalanceBefore = fraxBPPHOMetapool.balanceOf(address(this));

        pho.approve(address(fraxBPPHOMetapool), phoAmount);
        fraxBPLp.approve(address(fraxBPPHOMetapool), fraxBPLPAmount);

        uint256[2] memory metaLiquidity;
        metaLiquidity[0] = phoAmount;
        metaLiquidity[1] = fraxBPLPAmount;

        fraxBPPHOMetapool.add_liquidity(metaLiquidity, 0);

        uint256 fraxBPPHOLpBalanceAfter = fraxBPPHOMetapool.balanceOf(address(this));

        uint256 fraxBPPHOLpBalanceIssued = fraxBPPHOLpBalanceAfter - fraxBPPHOLpBalanceBefore;
        return fraxBPPHOLpBalanceIssued;
    }

    /// @notice user redeems and gets back FraxBP and PHO
    function redeem() external nonReentrant {
        if (block.timestamp < redemptionStartDate) {
            revert CannotRedeemBeforeRedemptionStart();
        }
        uint256 redeemAmount = metapoolBalance[msg.sender];
        if (redeemAmount == 0) {
            revert CannotRedeemZero();
        }

        delete metapoolBalance[msg.sender];
        fraxBPPHOMetapool.transfer(msg.sender, redeemAmount / 2);
        emit Redeemed(msg.sender, redeemAmount);
    }

    /// @notice gets USD per FraxBP LP by checking underlying asset composition (FRAX and USDC)
    /// @return usdPerFraxBP USD/FraxBP (normalized by d18) price answer derived from fraxBP balances and USD/Frax && USD/USDC priceFeeds
    function getUSDPerFraxBP() public returns (uint256) {
        uint256 fraxInFraxBP = fraxBPPool.balances(0); // FRAX - decimals: 18
        uint256 usdcInFraxBP = fraxBPPool.balances(1); // USDC - decimals: 6
        uint256 fraxPerFraxBP = (fraxInFraxBP * PRICE_PRECISION) / fraxBPLp.totalSupply(); // Units: (FRAX/FraxBP) - normalized by d18
        uint256 usdcPerFraxBP =
            (usdcInFraxBP * PRICE_PRECISION * USDC_SCALE) / fraxBPLp.totalSupply(); // Units: (USDC/FraxBP) - normalized by d18
        uint256 usdPerFraxBP = (
            ((fraxPerFraxBP * PRICE_PRECISION) / priceOracle.getPrice(address(frax)))
                + ((usdcPerFraxBP * PRICE_PRECISION) / priceOracle.getPrice(address(usdc)))
        ); // UNITS: (USD/FraxBP) - normalized by d18
        return usdPerFraxBP;
    }
}
