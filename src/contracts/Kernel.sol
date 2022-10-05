// SPDX-License-Identifier: GPL-3.0-or-later

import "../interfaces/IKernel.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IPHO.sol";

contract Kernel is IKernel, Ownable {

    error zeroAddressDetected();
    error zeroValueDetected();
    error calledNotApproved(address caller);
    error callerAlreadyApproved();
    error callerCeilingReached(uint256 ceiling, uint256 currentBalance, uint256 attemptedAmount);
    error newCeilingTooLow(uint256 currentCeiling, uint256 ceilingRequested);

    IPHO public pho;

    /// whitelisted contracts that can ask the Teller to mint
    mapping(address => uint256) public mintingWhitelist;

    /// tracks max $PHO that whitelisted accounts can ask for
    mapping(address => uint256) public mintingBalances;

    constructor(address _phoAddress) {
        pho = IPHO(_phoAddress);
    }

    /// @notice minting function for $PHO. only accessible to approved addresses
    /// @param to the user to mint $PHO to
    /// @param amount the amount of $PHO to mint
    function mintPHO(address to, uint256 amount) external {
        require(to != address(0), "Teller: zero address detected");
        require(mintingWhitelist[msg.sender] > 0, "Teller: caller is not approved");
        require(
            mintingBalances[msg.sender] + amount <= mintingWhitelist[msg.sender],
            "Teller: caller ceiling reached"
        );
        mintingBalances[msg.sender] += amount;
        pho.mint(to, amount);
    }

    /// @notice function to approve addresses of minting rights
    /// @param caller the requesting address to be approved minting rights
    /// @param ceiling the minting ceiling for the caller
    function whitelistCaller(address caller, uint256 ceiling) external onlyOwner {
        require(caller != address(0), "Teller: zero address detected");
        require(ceiling > 0, "Teller: zero value detected");
        require(mintingWhitelist[caller] == 0, "Teller: caller is already approved");
        mintingWhitelist[caller] = ceiling;
        emit CallerWhitelisted(caller, ceiling);
    }

    // TODO - We need to hook up the revoking and deleting to the totalPHOMinted. And start decrementing the totalPHOMinted.
    /// @notice function to revoke addresses of minting rights
    /// @param caller the address to be revoked minting rights
    function revokeCaller(address caller) external onlyOwner {
        require(caller != address(0), "Teller: zero address detected");
        require(mintingWhitelist[caller] > 0, "Teller: caller is not approved");
        delete mintingWhitelist[caller];
        delete mintingBalances[caller];
        emit CallerRevoked(caller);
    }

    /// @notice modify the caller's minting ceiling
    /// @param caller the address to modify it's ceiling
    /// @param newCeiling the new minting ceiling for the caller
    function modifyCallerCeiling(address caller, uint256 newCeiling) external onlyOwner {
        require(caller != address(0), "Teller: zero address detected");
        require(mintingWhitelist[caller] > 0, "Teller: caller is not approved");
        require(mintingBalances[caller] < newCeiling, "Teller: new ceiling too low");
        mintingWhitelist[caller] = newCeiling;
        emit CallerCeilingModified(caller, newCeiling);
    }
}
