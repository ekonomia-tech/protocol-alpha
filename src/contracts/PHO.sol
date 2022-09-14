// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IPHO.sol";

/// @title PHOTON protocol stablecoin
/// @author Ekonomia: https://github.com/Ekonomia

contract PHO is IPHO, ERC20Burnable, Ownable {
    address public controllerAddress;
    address public timelockAddress;
    address public tellerAddress;

    modifier onlyByOwnerGovernanceOrController() {
        require(
            msg.sender == owner() || msg.sender == timelockAddress
                || msg.sender == controllerAddress,
            "PHO: Not the owner, controller, or the governance timelock"
        );
        _;
    }

    modifier onlyTeller() {
        require(tellerAddress == msg.sender, "PHO: caller is not the teller");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        address _controllerAddress,
        address _timelockAddress
    )
        ERC20(_name, _symbol)
    {
        require(
            _controllerAddress != address(0) && _timelockAddress != address(0),
            "PHO: zero address detected"
        );
        timelockAddress = _timelockAddress;
        controllerAddress = _controllerAddress;
    }

    /// @notice burn pho. this function is open to everyone
    /// @param from the user to burn $PHO from
    /// @param amount the amount of $PHO to burn
    function burn(address from, uint256 amount) external {
        super.burnFrom(from, amount);
        emit PHOBurned(from, msg.sender, amount);
    }

    /// @notice mint new $PHO tokens
    /// @param to the user to mint $PHO to
    /// @param amount the amount to mint
    function mint(address to, uint256 amount) external onlyTeller {
        super._mint(to, amount);
        emit PHOMinted(msg.sender, to, amount);
    }

    /// @notice set the teller address, which will be the only address capable of minting and burning
    function setTeller(address newTeller) external onlyByOwnerGovernanceOrController {
        require(newTeller != address(0), "PHO: zero address detected");
        require(newTeller != tellerAddress, "PHO: same address detected");
        tellerAddress = newTeller;
        emit ControllerSet(tellerAddress);
    }

    /// @notice set controller (owner) of this contract
    function setController(address newController) external onlyByOwnerGovernanceOrController {
        require(newController != address(0), "PHO: zero address detected");
        require(newController != controllerAddress, "PHO: same address detected");
        controllerAddress = newController;
        emit ControllerSet(controllerAddress);
    }

    /// @notice set the timelock address to be used in this contract
    function setTimelock(address newTimelock) external onlyByOwnerGovernanceOrController {
        require(newTimelock != address(0), "PHO: zero address detected");
        require(newTimelock != timelockAddress, "PHO: same address detected");
        timelockAddress = newTimelock;
        emit TimelockSet(timelockAddress);
    }
}
