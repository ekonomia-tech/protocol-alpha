// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../oracle/DummyOracle.sol";
import "../interfaces/IVault.sol";

/// @title Vault contract
/// @notice Each vault hold a single collateral token
/// @author Ekonomia: https://github.com/Ekonomia

/// TODO: modify the contract after the oracle is updated

contract Vault is IVault, Ownable {
    IERC20Metadata public collateral;
    DummyOracle public priceOracle;

    /// list of whitelisted contracts to be provided with collateral from this vault
    mapping(address => bool) public whitelist;

    uint256 public constant PRICE_PRECISION = 10 ** 6;

    /// @param _collateralToken the collateral token held by this vault
    /// @param _oracleAddress address of the price oracle
    constructor(address _collateralToken, address _oracleAddress) {
        priceOracle = DummyOracle(_oracleAddress);
        collateral = IERC20Metadata(_collateralToken);
    }

    /// @notice getter for the collateral token of this vault
    function getVaultToken() external view returns (address) {
        return address(collateral);
    }

    /// @notice the collateral token price in USD
    /// @return uint256 the price of the token in USD
    function getTokenPriceUSD() external view returns (uint256) {
        /// returns USDC price for now, but will have to implement the oracle once its ready
        return priceOracle.getUSDCUSDPrice();
    }

    /// @notice the collateral value locked in the vault in USD
    /// @return uint256 d18 representation of USD value
    function getVaultUSDValue() external view returns (uint256) {
        uint256 balance = collateral.balanceOf(address(this)) * (10 ** (18 - collateral.decimals()));
        /// returns USDC price for now, but will have to implement the oracle once its ready
        uint256 collateralPrice = priceOracle.getUSDCUSDPrice();
        return balance * collateralPrice / PRICE_PRECISION;
    }

    /// @notice provide collateral to approved callers
    /// @param amount the amount to be provided to the caller
    function provide(uint256 amount) external {
        require(amount > 0, "Vault: zero amount detected");
        require(whitelist[msg.sender], "Vault: caller not approved");
        require(collateral.balanceOf(address(this)) >= amount, "Vault: not enough collateral");
        collateral.transfer(msg.sender, amount);
    }

    /// @notice function to approve addresses to be provided with collateral from this vault
    /// @param caller the requesting address to be provided with collateral from this vault
    function whitelistCaller(address caller) external onlyOwner {
        require(caller != address(0), "Vault: zero address detected");
        require(!whitelist[caller], "Vault: caller is already approved");
        whitelist[caller] = true;
        emit CallerWhitelisted(caller);
    }

    /// @notice function to revoke addresses from being provided collateral
    /// @param caller the address to revoke rights of collateral to be provided to
    function revokeCaller(address caller) external onlyOwner {
        require(caller != address(0), "Vault: zero address detected");
        require(whitelist[caller], "Vault: caller is not approved");
        delete whitelist[caller];
        emit CallerRevoked(caller);
    }

    /// @notice set the oracle address for this contract
    /// @param newOracleAddress the new address of the oracle used
    function setOracleAddress(address newOracleAddress) external onlyOwner {
        require(newOracleAddress != address(0), "Vault: zero address detected");
        require(newOracleAddress != address(priceOracle), "Vault: same address detected");
        priceOracle = DummyOracle(newOracleAddress);
        emit OracleAddressSet(address(priceOracle));
    }
}
