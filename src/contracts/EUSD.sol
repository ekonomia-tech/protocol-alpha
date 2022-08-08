// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import "lib/forge-std/src/Script.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import "lib/openzeppelin-contracts/contracts/utils/Context.sol";
// import "./Owned.sol"; // TODO assess compared to Governed.sol
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/// @title EUSD
/// @notice Fractional stablecoin
/// @author Ekonomia: https://github.com/Ekonomia
contract EUSD is ERC20, AccessControl, Ownable {

    string public symbol;
    string public name;
    uint8 public constant decimals = 18;
    address public creator_address; // This is made the owner, and then it is amongst timelock_address, and controller_address to be able to do unique things throughout the contract.
    address public timelock_address; // Governance timelock address - TODO - figure this out, seems like typical timelock
    uint256 public constant genesis_supply = 2000000e18; // TODO - assess how much is needed for us, could go with: 2M EUSD (only for testing, genesis supply will be 5k on Mainnet). This is to help with establishing the Uniswap pools, as they need liquidity
    address[] public EUSD_pools_array; // The addresses in this array are added by the oracle and these contracts are able to mint EUSD
    mapping(address => bool) public EUSD_pools; // Mapping is also used for faster verification
    address public DEFAULT_ADMIN_ADDRESS;

    /// TODO - confirm with Niv that this is how we want to go about it
    modifier onlyPools() {
       require(EUSD_pools[msg.sender] == true, "Only EUSD pools can call this function");
        _;
    } 
    
    /// TODO - confirm with Niv that this is how we want to go about it
    /// @params owner of EUSD contract
    /// @params time_lock_address stop-gap smart contract to require passed on-chain vote proposals to wait X blocks before implementation. This allows for users who disagree with the new changes to withdraw funds
    modifier onlyByOwnerGovernanceOrController() {
        require(msg.sender == owner || msg.sender == timelock_address || msg.sender == controller_address, "Not the owner, controller, or the governance timelock");
        _;
    }

    /// CONSTRUCTOR
    /// @params _name of ERC20
    /// @params _symbol of ERC20
    /// @params _creator_address owner multisig
    /// @params _timelock_address stop-gap smart contract for maturing on-chain implementation changes
     constructor (
        string memory _name,
        string memory _symbol,
        address _creator_address,
        address _timelock_address
    ) public Owned(_creator_address){
        require(_timelock_address != address(0), "Zero address detected"); 
        name = _name;
        symbol = _symbol;
        creator_address = _creator_address;
        timelock_address = _timelock_address;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        DEFAULT_ADMIN_ADDRESS = _msgSender();
        _mint(creator_address, genesis_supply);
    }

/// VIEW FUNCTIONS

    // Used by pools when user redeems
    function pool_burn_from(address b_address, uint256 b_amount) public onlyPools {
        super._burnFrom(b_address, b_amount);
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
        for (uint i = 0; i < EUSD_pools_array.length; i++){ 
            if (EUSD_pools_array[i] == pool_address) {
                EUSD_pools_array[i] = address(0); // This will leave a null in the array and keep the indices the same
                break;
            }
        }

        emit PoolRemoved(pool_address);
    }

    /// @notice set controller (owner) of this contract
    function setController(address _controller_address) external onlyByOwnerGovernanceOrController {
        require(_controller_address != address(0), "Zero address detected");

        controller_address = _controller_address;

        emit ControllerSet(_controller_address);
    }

}
