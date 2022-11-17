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
    error OnlyModuleManager();
    error CannotDepositZero();

    /// Events
    event BondIssued(
        address indexed depositor, uint256 usdcAmount, uint256 fraxAmount, uint256 mintAmount
    );
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
    IERC20Metadata public frax = IERC20Metadata(0x853d955aCEf822Db058eb8505911ED77F175b99e);
    IERC20Metadata public usdc = IERC20Metadata(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20Metadata public fraxBPLp = IERC20Metadata(0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC);
    ICurvePool public fraxBPPool = ICurvePool(0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2);
    ICurveFactory public curveFactory = ICurveFactory(0xB9fC157394Af804a3578134A6585C0dc9cc990d4);
    ICurvePool public fraxBPPHOMetapool;
    uint256 public maxCap;
    uint256 public constant FRAX_DECIMALS = 18;
    uint256 public constant USDC_DECIMALS = 6;
    uint256 private constant USDC_SCALE = 10 ** 12;
    uint256 public saleEndDate; // when sale ends
    address public kernel;
    IPHO public pho;

    mapping(address => uint256) public issuedAmount;

    modifier onlyModuleManager() {
        if (msg.sender != address(moduleManager)) revert OnlyModuleManager();
        _;
    }

    /// Constructor
    constructor(
        address _moduleManager,
        address _kernel,
        string memory _bondTokenName,
        string memory _bondTokenSymbol,
        address _fraxBPPHOMetapool,
        address _pho,
        uint256 _maxCap,
        uint256 _saleEndDate
    ) ERC20(_bondTokenName, _bondTokenSymbol) {
        if (
            _moduleManager == address(0) || _fraxBPPHOMetapool == address(0)
                || _kernel == address(0) || _pho == address(0)
        ) {
            revert ZeroAddressDetected();
        }
        moduleManager = IModuleManager(_moduleManager);
        fraxBPPHOMetapool = ICurvePool(_fraxBPPHOMetapool);
        kernel = _kernel;
        pho = IPHO(_pho);
        maxCap = _maxCap;
        saleEndDate = _saleEndDate;
    }

    /// @notice user deposits both FRAX and USDC
    /// @param usdcAmount USDC deposit amount
    /// @param fraxAmount FRAX deposit amount
    function deposit(uint256 usdcAmount, uint256 fraxAmount) external nonReentrant {
        if (block.timestamp > saleEndDate) {
            revert CannotDepositAfterSaleEnded();
        }
        uint256 totalAmount = usdcAmount * USDC_SCALE + fraxAmount;
        if (totalAmount == 0) {
            revert CannotDepositZero();
        }

        // transfer USDC and FRAX from caller
        usdc.safeTransferFrom(msg.sender, address(this), usdcAmount);
        frax.safeTransferFrom(msg.sender, address(this), fraxAmount);

        issuedAmount[msg.sender] += totalAmount;
        _mint(msg.sender, totalAmount);

        emit BondIssued(msg.sender, usdcAmount, fraxAmount, totalAmount);
    }

    /// @notice Adds PHO and FraxBP LP to FraxBP/PHO pool
    function addFraxBPPHOLiquidity() external {
        // Steps:
        // 1. Adds USDC and FRAX (say N total) to FraxBP in order to get FraxBP LP tokens
        // 2. Mints N/2 PHO based on USDC and FRAX amounts
        // 3. Add liquidity to fraxBP PHO pool

        uint256 usdcAmount = usdc.balanceOf(address(this));
        uint256 fraxAmount = frax.balanceOf(address(this));

        uint256[2] memory fraxBPmetaLiquidity;
        fraxBPmetaLiquidity[0] = fraxAmount; // frax
        fraxBPmetaLiquidity[1] = usdcAmount; // usdc

        usdc.approve(address(fraxBPPool), usdcAmount);
        frax.approve(address(fraxBPPool), fraxAmount);

        fraxBPPool.add_liquidity(fraxBPmetaLiquidity, 0);

        uint256 fraxBPLPAmount = fraxBPLp.balanceOf(address(this));

        if (usdcAmount * USDC_SCALE != fraxAmount) {
            revert MustHaveEqualAmounts();
        }

        uint256 phoAmount = fraxAmount * 2;

        moduleManager.mintPHO(address(this), phoAmount);

        pho.approve(address(fraxBPPHOMetapool), phoAmount);
        fraxBPLp.approve(address(fraxBPPHOMetapool), fraxBPLPAmount);

        uint256[2] memory metaLiquidity;
        metaLiquidity[0] = phoAmount;
        metaLiquidity[1] = fraxBPLPAmount;

        ICurvePool(fraxBPPHOMetapool).add_liquidity(metaLiquidity, 0);
    }

    /// @notice user redeems and gets back PHO
    function redeem() external nonReentrant {
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
        _burn(msg.sender, redeemAmount);

        emit BondRedeemed(msg.sender, redeemAmount);
    }
}
