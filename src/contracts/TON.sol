// SPDX-License-Identifier: GPL-3.0-or-later
// Inspired by Frax
// https://github.com/FraxFinance/frax-solidity/blob/7cbe89981ffa5d3cd0eeaf62dd1489c3276de0e4/src/hardhat/contracts/FXS/FXS.sol
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/ITON.sol";

contract TON is ITON, ERC20Burnable, Ownable {
    uint256 public constant genesis_supply = 100000000 * 10 ** 18;

    address public timelockAddress;
    address public controllerAddress;
    address public tellerAddress;

    modifier onlyByOwnerGovernanceOrController() {
        require(
            msg.sender == owner() || msg.sender == timelockAddress
                || msg.sender == controllerAddress,
            "TON: Not the owner, controller, or the governance timelock"
        );
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
            "TON: zero address detected"
        );
        controllerAddress = _controllerAddress;
        timelockAddress = _timelockAddress;

        _mint(msg.sender, genesis_supply);
    }

    /// @notice setting the timelock address
    function setTimelock(address newTimelock) external onlyByOwnerGovernanceOrController {
        require(newTimelock != address(0), "TON: zero address detected");
        require(newTimelock != timelockAddress, "TON: same address detected");
        timelockAddress = newTimelock;
        emit TimelockSet(timelockAddress);
    }

    /// @notice setting the controller address
    function setController(address newController) external onlyByOwnerGovernanceOrController {
        require(newController != address(0), "TON: zero address detected");
        require(newController != controllerAddress, "TON: same address detected");
        controllerAddress = newController;
        emit ControllerSet(controllerAddress);
    }

    /// @notice $TON burning function. can only be executed by controller or gov or owner
    /// @param from the user to burn $TON from
    /// @param amount the amount of $TON to burn
    function burn(address from, uint256 amount) external onlyByOwnerGovernanceOrController {
        super.burnFrom(from, amount);
        emit TONBurned(from, amount);
    }
}
