// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@protocol/interfaces/IPHO.sol";
import "@protocol/interfaces/IModuleManager.sol";
import "@external/curve/ICurvePool.sol";
import "@external/curve/ICurveFactory.sol";
import "forge-std/console2.sol";

/// @title FraxBP Init module
/// @author Ekonomia: https://github.com/ekonomia-tech
/// @notice Accepts FRAX & USDC
contract FraxBPInitModule is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20Metadata;

    /// Errors
    error ZeroAddressDetected();
    error CannotRedeemMoreThanDeposited();
    error OverEighteenDecimals();
    error CannotDepositAfterSaleEnded();
    error MaxCapNotMet();
    error FraxBPPHOMetapoolNotSet();
    error MustHaveEqualAmounts();

    /// Events
    event BondIssued(address indexed depositor, uint256 depositAmount, uint256 mintAmount);
    event BondRedeemed(address indexed redeemer, uint256 redeemAmount);
    event TokensExchanged(
        address indexed dexPool,
        address indexed tokenSent,
        uint256 amountSent,
        address tokenReceived,
        uint256 amountReceived
    );

    /// State vars
    IModuleManager public moduleManager;
    IERC20Metadata public frax;
    IERC20Metadata public usdc;
    //IERC20 public usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20Metadata public fraxBPLp;
    ICurvePool public fraxBPPool;
    ICurveFactory public curveFactory = ICurveFactory(0xB9fC157394Af804a3578134A6585C0dc9cc990d4);
    address public fraxBPPHOMetapool;
    uint256 public maxCap;
    uint256 public currentDeposits;
    uint256 public constant FRAX_DECIMALS = 18;
    uint256 public constant USDC_DECIMALS = 6;
    address public kernel;
    IPHO public pho;
    bool public saleEnded; // did sale end
    mapping(address => uint256) public issuedAmount;

    // TODO:
    uint256 public maxSlippage = 10 ** 5;
    uint256 private constant PERCENTAGE_PRECISION = 10 ** 5;
    uint256 private constant USDC_SCALE = 10 ** 12;

    modifier onlyModuleManager() {
        require(msg.sender == address(moduleManager), "Only ModuleManager");
        _;
    }

    /// Constructor
    constructor(
        address _moduleManager,
        address _kernel,
        string memory _bondTokenName,
        string memory _bondTokenSymbol,
        address _frax,
        address _usdc,
        address _fraxBPLp,
        address _fraxBPPool,
        address _pho,
        uint256 _maxCap
    ) ERC20(_bondTokenName, _bondTokenSymbol) {
        if (
            _moduleManager == address(0) || _frax == address(0) || _usdc == address(0)
                || _fraxBPLp == address(0) || _fraxBPPool == address(0) || _kernel == address(0)
                || _pho == address(0)
        ) {
            revert ZeroAddressDetected();
        }
        moduleManager = IModuleManager(_moduleManager);
        frax = IERC20Metadata(_frax);
        usdc = IERC20Metadata(_usdc);
        fraxBPLp = IERC20Metadata(_fraxBPLp);
        fraxBPPool = ICurvePool(_fraxBPPool);
        kernel = _kernel;
        pho = IPHO(_pho);
        maxCap = _maxCap;
    }

    /// @notice user deposits both FRAX and USDC
    /// @param depositAmount deposit amount
    function deposit(uint256 depositAmount) external nonReentrant {
        if (saleEnded) {
            revert CannotDepositAfterSaleEnded();
        }
        // scale if decimals < 18
        uint256 fraxDepositAmount = depositAmount;
        uint256 usdcDepositAmount = depositAmount / (10 ** (18 - USDC_DECIMALS));

        // transfer FRAX and USDC from caller
        frax.safeTransferFrom(msg.sender, address(this), fraxDepositAmount);
        usdc.safeTransferFrom(msg.sender, address(this), usdcDepositAmount);

        issuedAmount[msg.sender] += depositAmount;
        currentDeposits += depositAmount;
        _mint(msg.sender, depositAmount);

        emit BondIssued(msg.sender, depositAmount, depositAmount);
    }

    /// @notice Sets whether sale ended
    function setSaleEnded(bool _saleEnded) external onlyOwner {
        saleEnded = _saleEnded;
    }

    /// @notice sets FraxBP/PHO pool
    /// @param _fraxBPPHOMetapool FraxBP / PHO mpool
    function setFraxBpPHOPool(address _fraxBPPHOMetapool) external onlyOwner {
        if (_fraxBPPHOMetapool == address(0)) {
            revert ZeroAddressDetected();
        }
        fraxBPPHOMetapool = _fraxBPPHOMetapool;
    }

    /// @notice Adds USDC and FRAX to FraxBP in order to get FraxBP LP tokens
    /// @param usdcAmount amount of USDC to deposit
    /// @param fraxAmount amount of FRAX to deposit
    function addFraxBPLiquidity(uint256 usdcAmount, uint256 fraxAmount)
        external
        onlyOwner
        returns (uint256)
    {
        uint256[2] memory fraxBPmetaLiquidity;
        fraxBPmetaLiquidity[0] = fraxAmount; // frax
        fraxBPmetaLiquidity[1] = usdcAmount; // usdc

        usdc.approve(address(fraxBPPool), usdcAmount);
        frax.approve(address(fraxBPPool), fraxAmount);

        fraxBPPool.add_liquidity(fraxBPmetaLiquidity, 0);

        uint256 fraxBPLPbalanceAfter = fraxBPLp.balanceOf(address(this));
        return fraxBPLPbalanceAfter;
    }

    /// @notice Adds PHO and FraxBP LP to FraxBP/PHO pool
    /// @param fraxBPLPAmuont amount of FRAXBP LP token to deposit
    /// @param usdcAmount amount of USDC to deposit
    /// @param fraxAmount amount of FRAX to deposit
    function addFraxBPPHOLiquidity(uint256 fraxBPLPAmuont, uint256 usdcAmount, uint256 fraxAmount)
        external
    {
        // mint N/2 PHO based on USDC and FRAX amounts
        // then add liquidity to fraxBP PHO pool

        if (usdcAmount * USDC_SCALE != fraxAmount) {
            revert MustHaveEqualAmounts();
        }

        uint256 phoAmount = fraxAmount * 2;

        pho.approve(fraxBPPHOMetapool, phoAmount);
        fraxBPLp.approve(fraxBPPHOMetapool, fraxBPLPAmuont);

        uint256[2] memory metaLiquidity;
        metaLiquidity[0] = phoAmount;
        metaLiquidity[1] = fraxBPLPAmuont;

        ICurvePool(fraxBPPHOMetapool).add_liquidity(metaLiquidity, 0);
    }

    /// @notice user redeems and gets back PHO
    function redeem() external nonReentrant {
        if (fraxBPPHOMetapool == address(0)) {
            revert FraxBPPHOMetapoolNotSet();
        }
        uint256 redeemAmount = issuedAmount[msg.sender];
        issuedAmount[msg.sender] -= redeemAmount;

        uint256 fraxBPLPbalanceBefore = fraxBPLp.balanceOf(address(this));

        uint256 phoBalanceBefore = pho.balanceOf(address(this));

        // Remove liquidity from Frax BP / PHO Metapool
        uint256[2] memory minAmounts = [uint256(0), uint256(0)];
        ICurvePool(fraxBPPHOMetapool).remove_liquidity(redeemAmount, minAmounts, address(this));

        uint256 fraxBPLPbalanceAfter = fraxBPLp.balanceOf(address(this));

        uint256 phoBalanceAfter = pho.balanceOf(address(this));

        uint256 fraxBPLPBalanceToSend = fraxBPLPbalanceAfter - fraxBPLPbalanceBefore;

        uint256 phoBalanceToSend = phoBalanceAfter - phoBalanceBefore;

        // Send user back FraxBP LP and PHO
        fraxBPLp.transfer(msg.sender, fraxBPLPBalanceToSend);
        pho.transfer(msg.sender, phoBalanceToSend);

        emit BondRedeemed(msg.sender, redeemAmount);
    }
}
