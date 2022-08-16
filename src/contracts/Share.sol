// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "openzeppelin-contracts/contracts/utils/Context.sol";
import "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/access/AccessControl.sol";
import "./EUSD.sol";

contract Share is ERC20Burnable, AccessControl, Ownable {
    
    uint256 public constant genesis_supply = 100000000*10**18;

    address public oracle_address;
    address public timelock_address;
    EUSD public eusd;

    modifier onlyPools() {
        require(eusd.EUSD_pools(msg.sender) == true, "Only eusd pools can mint or burn SHARE");
        _;
    } 
    
    modifier onlyByOwnGov() {
        require(msg.sender == owner() || msg.sender == timelock_address, "You are not an owner or the governance timelock");
        _;
    }

    event ShareBurned(address indexed from, address indexed to, uint256 amount);
    event ShareMinted(address indexed from, address indexed to, uint256 amount);
    event EUSDAddressSet(address newAddress);

    constructor (
        string memory _name,
        string memory _symbol, 
        address _oracle_address,
        address _timelock_address
    ) ERC20(_name, _symbol) {
        require((_oracle_address != address(0)) && (_timelock_address != address(0)), "Zero address detected"); 

        oracle_address = _oracle_address;
        timelock_address = _timelock_address;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _mint(_msgSender(), genesis_supply);
    }

    function setOracle(address new_oracle) external onlyByOwnGov {
        require(new_oracle != address(0), "Zero address detected");
        oracle_address = new_oracle;
    }

    function setTimelock(address new_timelock) external onlyByOwnGov {
        require(new_timelock != address(0), "Timelock address cannot be 0");
        timelock_address = new_timelock;
    }
    
    function setEUSDAddress(address eusd_contract_address) external onlyByOwnGov {
        require(eusd_contract_address != address(0), "Zero address detected");

        eusd = EUSD(eusd_contract_address);

        emit EUSDAddressSet(eusd_contract_address);
    }
    
    function mint(address to, uint256 amount) public onlyPools {
        super._mint(to, amount);
    }
    
    function pool_mint(address m_address, uint256 m_amount) external onlyPools {        
        mint(m_address, m_amount);
        emit ShareMinted(address(this), m_address, m_amount);
    }

    function pool_burn_from(address b_address, uint256 b_amount) external onlyPools {
        burnFrom(b_address, b_amount);
        emit ShareBurned(b_address, address(this), b_amount);
    }
}