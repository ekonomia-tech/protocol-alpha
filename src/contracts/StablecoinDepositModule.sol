// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IPHO.sol";

/// @title StablecoinDepositModule
/// @author Ekonomia: https://github.com/ekonomia-tech
/// @notice Accepts stablecoins 1:1 i.e. LUSD, DAI, etc.
contract StablecoinDepositModule is Ownable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    /// Errors
    error ZeroAddressDetected();
    error CannotRedeemMoreThanDeposited();
    error StablecoinNotWhitelisted();

    /// State vars
    address public dispatcher;
    address public teller;
    IPHO public pho;
    mapping(address => bool) public stablecoinWhitelist;
    mapping(address => mapping(address => uint256)) public issuedAmount;

    /// Events
    event StablecoinWhitelisted(address indexed stablecoin);
    event StablecoinDelisted(address indexed stablecoin);
    event StablecoinDeposited(
        address indexed stablecoin, address indexed depositor, uint256 depositAmount
    );
    event StablecoinRedeemed(
        address indexed stablecoin, address indexed redeemer, uint256 redeemAmount
    );

    modifier onlyDispatcher() {
        require(msg.sender == dispatcher, "Only dispatcher");
        _;
    }

    /// Constructor
    constructor(address _dispatcher, address _teller, address _pho) {
        if (_dispatcher == address(0) || _teller == address(0) || _pho == address(0)) {
            revert ZeroAddressDetected();
        }
        dispatcher = _dispatcher;
        teller = _teller;
        pho = IPHO(_pho);
    }

    /// @notice add whitelisted stablecoin
    /// @param stablecoin the stablecoin address to whitelist
    function addStablecoin(address stablecoin) external onlyOwner {
        if (stablecoin == address(0)) {
            revert ZeroAddressDetected();
        }
        stablecoinWhitelist[stablecoin] = true;
        emit StablecoinWhitelisted(stablecoin);
    }

    /// @notice remove whitelisted stablecoin
    /// @param stablecoin the stablecoin address to remove from whitelist
    function removeStablecoin(address stablecoin) external onlyOwner {
        if (stablecoin == address(0)) {
            revert ZeroAddressDetected();
        }
        delete stablecoinWhitelist[stablecoin];
        emit StablecoinDelisted(stablecoin);
    }

    /// @notice user deposits their stablecoin
    /// @param depositAmount deposit amount (in stablecoin decimals)
    function depositStablecoin(address stablecoin, uint256 depositAmount) external nonReentrant {
        if (!stablecoinWhitelist[stablecoin]) {
            revert StablecoinNotWhitelisted();
        }
        // scale if decimals < 18
        uint256 scaledDepositAmount = depositAmount;
        uint256 stablecoinDecimals = IERC20Metadata(stablecoin).decimals();
        scaledDepositAmount = depositAmount * (10 ** (18 - stablecoinDecimals));

        // transfer stablecoin
        ERC20(stablecoin).safeTransferFrom(msg.sender, address(this), depositAmount);

        issuedAmount[stablecoin][msg.sender] += scaledDepositAmount;

        // TOOD: mintPHO()
        pho.transfer(msg.sender, scaledDepositAmount);

        emit StablecoinDeposited(address(stablecoin), msg.sender, depositAmount);
    }

    /// @notice user redeems PHO for their original stablecoin
    /// @param redeemAmount redeem amount in terms of PHO - 18 decimals
    function redeemStablecoin(address stablecoin, uint256 redeemAmount) external nonReentrant {
        if (!stablecoinWhitelist[stablecoin]) {
            revert StablecoinNotWhitelisted();
        }
        if (redeemAmount > issuedAmount[stablecoin][msg.sender]) {
            revert CannotRedeemMoreThanDeposited();
        }

        issuedAmount[stablecoin][msg.sender] -= redeemAmount;

        // caller gives PHO
        ERC20(address(pho)).safeTransferFrom(msg.sender, address(this), redeemAmount);

        // TODO: burnPho()

        // scale if decimals < 18
        uint256 scaledRedeemAmount = redeemAmount;
        uint256 stablecoinDecimals = IERC20Metadata(stablecoin).decimals();
        scaledRedeemAmount = redeemAmount / (10 ** (18 - stablecoinDecimals));

        // transfer stablecoin to caller
        ERC20(stablecoin).transfer(msg.sender, scaledRedeemAmount);

        emit StablecoinRedeemed(address(stablecoin), msg.sender, redeemAmount);
    }

    /// @notice mint PHO
    /// @param amount amount of PHO to mint
    function mintPho(uint256 amount) external onlyDispatcher {
        //TODO: replace stub
        //teller.mintPHO(address(this), amount);
    }

    /// @notice burn PHO
    /// @param amount amount of PHO to burn
    function burnPho(uint256 amount) external onlyDispatcher {
        //TODO: replace stub
        //teller.mintPHO(address(this), amount);
    }
}
