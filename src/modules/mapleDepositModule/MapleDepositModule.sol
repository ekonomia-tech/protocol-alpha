// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@protocol/interfaces/IPHO.sol";
import "@protocol/interfaces/IModuleManager.sol";
import "@protocol/interfaces/IModuleManager.sol";
import "@oracle/DummyOracle.sol";
import "./IMplRewards.sol";

/// @title MapleDepositModule
/// @author Ekonomia: https://github.com/ekonomia-tech
/// @notice Accepts MPL
contract MapleDepositModule is Ownable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    /// Errors
    error ZeroAddressDetected();
    error CannotRedeemMoreThanDeposited();
    error NotEighteenDecimals();
    error CannotStakeMoreThanDeposited();
    error CannotWithdrawMoreThanStaked();

    /// State vars
    IModuleManager public moduleManager;
    address public mapleToken;
    address public kernel;
    IPHO public pho;
    DummyOracle public oracle;
    IMplRewards public mplRewards;
    mapping(address => uint256) public depositedAmount; // MPL deposited
    mapping(address => uint256) public issuedAmount; // PHO issued
    mapping(address => uint256) public stakedAmount; // MPL staked

    /// Events
    event MapleDeposited(address indexed depositor, uint256 depositAmount, uint256 phoMinted);
    event MapleRedeemed(address indexed redeemer, uint256 redeemAmount, uint256 mplRedeemed);

    modifier onlyModuleManager() {
        require(msg.sender == address(moduleManager), "Only ModuleManager");
        _;
    }

    /// Constructor
    constructor(
        address _moduleManager,
        address _mapleToken,
        address _kernel,
        address _pho,
        address _oracle,
        address _mplRewards
    ) {
        if (
            _moduleManager == address(0) || _mapleToken == address(0) || _kernel == address(0)
                || _pho == address(0) || _oracle == address(0) || _mplRewards == address(0)
        ) {
            revert ZeroAddressDetected();
        }
        moduleManager = IModuleManager(_moduleManager);
        mapleToken = _mapleToken;
        if (IERC20Metadata(mapleToken).decimals() != 18) {
            revert NotEighteenDecimals();
        }
        kernel = _kernel;
        pho = IPHO(_pho);
        oracle = DummyOracle(_oracle);
        mplRewards = IMplRewards(mplRewards);
    }

    /// @notice user deposits their mapleToken
    /// @param depositAmount deposit amount (in mapleToken decimals)
    function depositMaple(uint256 depositAmount) external nonReentrant {
        // 18 decimals
        uint256 scaledDepositAmount = depositAmount;

        // transfer mapleToken
        ERC20(mapleToken).safeTransferFrom(msg.sender, address(this), depositAmount);

        uint256 phoMinted = (oracle.getMPLPHOPrice() / 10 ** 18) * scaledDepositAmount;

        depositedAmount[msg.sender] += depositAmount;
        issuedAmount[msg.sender] += phoMinted;
        moduleManager.mintPHO(msg.sender, phoMinted);

        emit MapleDeposited(msg.sender, depositAmount, phoMinted);
    }

    /// @notice user redeems PHO for their original mapleToken
    /// @param redeemAmount redeem amount in terms of PHO - 18 decimals
    function redeemMaple(uint256 redeemAmount) external nonReentrant {
        if (redeemAmount > issuedAmount[msg.sender]) {
            revert CannotRedeemMoreThanDeposited();
        }

        issuedAmount[msg.sender] -= redeemAmount;

        // TODO: what if it is all being staked?

        // MapleBalance memory m = mapleBalances[msg.sender];
        // m.issuedAmount -= redeemAmount;

        // caller gives PHO
        ERC20(address(pho)).safeTransferFrom(msg.sender, address(this), redeemAmount);

        // 18 decimals
        uint256 scaledRedeemAmount = redeemAmount;
        uint256 mplRedeemed = scaledRedeemAmount / ((oracle.getMPLPHOPrice() / 10 ** 18));

        depositedAmount[msg.sender] -= mplRedeemed;

        // transfer mapleToken to caller
        ERC20(mapleToken).transfer(msg.sender, mplRedeemed);

        emit MapleRedeemed(msg.sender, redeemAmount, mplRedeemed);
    }

    /// @notice stake via MplRewards
    function stakeMaple(uint256 amount) external {
        uint256 mplDeposited = depositedAmount[msg.sender];
        if (amount > mplDeposited) {
            revert CannotStakeMoreThanDeposited();
        }
        stakedAmount[msg.sender] += amount;
        mplRewards.stake(amount);
    }

    /// @notice withdraw via MplRewards
    function withdrawMaple(uint256 amount) external {
        uint256 mplStaked = stakedAmount[msg.sender];
        if (amount > mplStaked) {
            revert CannotWithdrawMoreThanStaked();
        }
        stakedAmount[msg.sender] -= amount;
        mplRewards.withdraw(amount);
    }

    /// @notice getReward via MplRewards
    function getRewardMaple(uint256 amount) external {
        uint256 mplStaked = stakedAmount[msg.sender];
        if (amount > mplStaked) {
            revert CannotWithdrawMoreThanStaked();
        }
        stakedAmount[msg.sender] -= amount;
        mplRewards.withdraw(amount);
    }
}
