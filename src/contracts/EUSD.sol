// SPDX-License-Identifier: GPL-3.0-or-later
// Inpired by Frax
// https://github.com/FraxFinance/frax-solidity/blob/7cbe89981ffa5d3cd0eeaf62dd1489c3276de0e4/src/hardhat/contracts/Frax/Frax.sol
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IEUSD.sol";

/// @title EUSD
/// @notice Fractional stablecoin
/// @author Ekonomia: https://github.com/Ekonomia
contract EUSD is IEUSD, ERC20Burnable, AccessControl, Ownable {
    string public SYMBOL;
    string public NAME;
    // uint8 public constant decimals = 18;
    address public creator_address; // This is made the owner, and then it is amongst timelock_address, and controller_address to be able to do unique things throughout the contract.
    address public controller_address;
    address public timelock_address; // Governance timelock address - TODO - figure this out, seems like typical timelock
    address[] public EUSD_pools_array; // The addresses in this array are added by the oracle and these contracts are able to mint EUSD
    mapping(address => bool) public EUSD_pools; // Mapping is also used for faster verification

    // address public DEFAULT_ADMIN_ADDRESS; // TODO - Need to sort out accessRoles and how we are going to use them.

    /// TODO - confirm with Niv that this is how we want to go about it
    modifier onlyPools() {
        require(EUSD_pools[msg.sender] == true, "Only EUSD pools can call this function");
        _;
    }

    /// TODO - confirm with Niv that this is how we want to go about it
    /// params owner of EUSD contract
    /// params time_lock_address stop-gap smart contract to require passed on-chain vote proposals to wait X blocks before implementation. This allows for users who disagree with the new changes to withdraw funds
    modifier onlyByOwnerGovernanceOrController() {
        require(
            msg.sender == owner() || msg.sender == timelock_address || msg.sender == controller_address,
            "Not the owner, controller, or the governance timelock"
        );
        _;
    }

    /// CONSTRUCTOR
    /// params _name of ERC20
    /// params _symbol of ERC20
    /// params _creator_address owner multisig
    /// params _timelock_address stop-gap smart contract for maturing on-chain implementation changes
    constructor(
        string memory _name,
        string memory _symbol,
        address _creator_address,
        address _timelock_address
    )
        ERC20(_name, _symbol)
    {
        require(_timelock_address != address(0), "Zero address detected");
        NAME = _name;
        SYMBOL = _symbol;
        creator_address = _creator_address;
        timelock_address = _timelock_address;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        // DEFAULT_ADMIN_ADDRESS = _msgSender();
        // _mint(creator_address, genesis_supply);
    }

    /// FUNCTIONS

    // get pool count
    function getPoolCount() public view returns (uint256) {
        return EUSD_pools_array.length;
    }

    // Used by pools when user redeems
    function pool_burn_from(address b_address, uint256 b_amount) public onlyPools {
        super.burnFrom(b_address, b_amount);
        emit EUSDBurned(b_address, msg.sender, b_amount);
    }

    // This function is what other EUSD pools will call to mint new EUSD
    function pool_mint(address m_address, uint256 m_amount) public onlyPools {
        super._mint(m_address, m_amount);
        emit EUSDMinted(msg.sender, m_address, m_amount);
    }

    // Adds collateral addresses supported, such as tether and busd, must be ERC20
    function addPool(address pool_address) public onlyByOwnerGovernanceOrController {
        require(pool_address != address(0), "Zero address detected");

        require(EUSD_pools[pool_address] == false, "Address already exists");
        EUSD_pools[pool_address] = true;
        EUSD_pools_array.push(pool_address);

        emit PoolAdded(pool_address);
    }

    // Remove a pool
    function removePool(address pool_address) public onlyByOwnerGovernanceOrController {
        require(pool_address != address(0), "Zero address detected");
        require(EUSD_pools[pool_address] == true, "Address nonexistant");

        // Delete from the mapping
        delete EUSD_pools[pool_address];

        // 'Delete' from the array by setting the address to 0x0
        for (uint256 i = 0; i < EUSD_pools_array.length; i++) {
            if (EUSD_pools_array[i] == pool_address) {
                EUSD_pools_array[i] = address(0); // This will leave a null in the array and keep the indices the same
                break;
            }
        }

        emit PoolRemoved(pool_address);
    }

    /// @notice set controller (owner) of this contract
    function setController(address _controller_address)
        external
        onlyByOwnerGovernanceOrController
    {
        require(_controller_address != address(0), "Zero address detected");

        controller_address = _controller_address;

        emit ControllerSet(_controller_address);
    }
}
