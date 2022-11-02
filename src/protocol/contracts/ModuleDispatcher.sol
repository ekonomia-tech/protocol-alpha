// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../interfaces/IModuleTokenFactory.sol";
import "../interfaces/IModuleRewardFactory.sol";
import "../interfaces/IModuleRewardPool.sol";
import "../interfaces/IModule.sol";
import "../interfaces/IModuleTokenMinter.sol";
import "../interfaces/IModuleDispatcher.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title ModuleDispatcher
/// @notice Dispatcher for modules
/// @author Ekonomia: https://github.com/Ekonomia
contract ModuleDispatcher is IModuleDispatcher {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address public owner;
    address public feeManager;
    address public poolManager;
    address public immutable staker;
    address public immutable minter;
    address public rewardFactory;
    address public tokenFactory;
    address public treasury;
    address public stakerRewards; //cvx rewards
    address public lockRewards; //cvxCrv rewards(crv)

    struct ModulePoolInfo {
        address module; // module
        address lptoken; // deposit token to module
        address token; // tokenized deposit
        address source; // source of yield i.e. Maple, Curve, etc.
        address rewardToken; // reward token i.e. MPL, CRV, etc.
        address rewards; // rewards contract linked to module
    }

    // moduleId -> modulePoolInfo
    ModulePoolInfo[] public modulePoolInfo;
    mapping(address => bool) public sourceMap;

    event Deposited(address indexed user, uint256 indexed modulePoolId, uint256 amount);
    event Withdrawn(address indexed user, uint256 indexed modulePoolId, uint256 amount);

    /// Constructor
    constructor(address _staker, address _minter) public {
        staker = _staker;
        owner = msg.sender;
        feeManager = msg.sender;
        poolManager = msg.sender;
        treasury = address(0);
        minter = _minter;
    }

    /// Setters

    /// Set Owner
    /// TODO: consolidate
    function setOwner(address _owner) external {
        require(msg.sender == owner, "Must be owner");
        owner = _owner;
    }

    /// Set FeeManager
    /// TODO: consolidate
    function setFeeManager(address _feeM) external {
        require(msg.sender == feeManager, "Must be FeeManager");
        feeManager = _feeM;
    }

    /// Set PoolManager
    /// TODO: consolidate
    function setPoolManager(address _poolManager) external {
        require(msg.sender == poolManager, "Must be PoolManager");
        poolManager = _poolManager;
    }

    /// Set Factories
    /// TODO: consolidate
    function setFactories(address _rewardFactory, address _tokenFactory) external {
        require(msg.sender == owner, "Must be owner");

        // Only set once at beginning
        if (rewardFactory == address(0)) {
            rewardFactory = _rewardFactory;
            tokenFactory = _tokenFactory;
        }
    }

    /// Set Reward contracts
    /// TODO: consolidate
    function setRewardContracts(address _rewards, address _stakerRewards) external {
        require(msg.sender == owner, "Must be owner");

        //reward contracts are immutable or else the owner
        //has a means to redeploy and mint cvx via rewardClaimed()
        if (lockRewards == address(0)) {
            lockRewards = _rewards;
            stakerRewards = _stakerRewards;
        }
    }

    /// Set fees
    /// TODO: consolidate
    function setFees(uint256 _stakerFees, uint256 _callerFees, uint256 _platform) external {
        // TODO: stubbed out
    }

    /// @notice Set treasury
    /// @param _treasury treasury
    function setTreasury(address _treasury) external {
        require(msg.sender == feeManager, "Must be FeeManager");
        treasury = _treasury;
    }

    /// @notice Deposits LP token and stake
    /// @param _module Module
    /// @param _depositToken Deposit token
    /// @param _source Source of yield
    function addModuleRewardPool(
        address _module,
        address _depositToken,
        address _source,
        address _rewardToken
    ) external returns (bool) {
        require(msg.sender == poolManager, "Must be PoolManager");
        require(
            _module != address(0) && _depositToken != address(0) && _source != address(0),
            "Zero address detected"
        );

        // Next module's modulePoolId
        uint256 modulePoolId = modulePoolInfo.length;

        // Tokenized deposit
        address token = IModuleTokenFactory(tokenFactory).createModuleDepositToken(_depositToken);

        // Reward contract
        address newRewardPool =
            IModuleRewardFactory(rewardFactory).createRewards(modulePoolId, token, _rewardToken);

        // Add new module pool info
        modulePoolInfo.push(
            ModulePoolInfo({
                lptoken: _depositToken,
                token: token,
                module: _module,
                source: _source,
                rewardToken: _rewardToken,
                rewards: newRewardPool
            })
        );
        sourceMap[_source] = true;
        return true;
    }

    /// @notice Deposits LP token and stake
    /// @param _modulePoolId Module pool ID
    /// @param _amount Amount to deposit
    /// @param _stake Whether to stake for user
    function deposit(uint256 _modulePoolId, uint256 _amount, bool _stake) public returns (bool) {
        ModulePoolInfo storage modulePoolInfo = modulePoolInfo[_modulePoolId];

        // Transfer lp token
        address lptoken = modulePoolInfo.lptoken;
        IERC20(lptoken).safeTransferFrom(msg.sender, staker, _amount);

        // Stake
        address source = modulePoolInfo.source;
        require(source != address(0), "Zero address");
        IModule(staker).deposit(lptoken, source);

        address token = modulePoolInfo.token;
        if (_stake) {
            IModuleTokenMinter(token).mint(address(this), _amount);
            address rewardContract = modulePoolInfo.rewards;
            IERC20(token).safeApprove(rewardContract, 0);
            IERC20(token).safeApprove(rewardContract, _amount);
            IModuleRewardPool(rewardContract).stakeFor(msg.sender, _amount);
        } else {
            //add user balance directly
            IModuleTokenMinter(token).mint(msg.sender, _amount);
        }

        emit Deposited(msg.sender, _modulePoolId, _amount);
        return true;
    }

    /// @notice Deposits LP token and stake
    /// @param _moduleId Module ID
    /// @param _stake Whether to stake for user
    function depositAll(uint256 _moduleId, bool _stake) external returns (bool) {
        address lptoken = modulePoolInfo[_moduleId].lptoken;
        uint256 balance = IERC20(lptoken).balanceOf(msg.sender);
        deposit(_moduleId, balance, _stake);
        return true;
    }

    /// @notice Withdraw LP tokens
    /// @param _moduleId Module ID
    /// @param _amount Amount
    /// @param _from From
    /// @param _to To
    function _withdraw(uint256 _moduleId, uint256 _amount, address _from, address _to) internal {
        ModulePoolInfo storage modulePoolInfo = modulePoolInfo[_moduleId];
        address lptoken = modulePoolInfo.lptoken;
        address source = modulePoolInfo.source;

        //remove lp balance
        address token = modulePoolInfo.token;
        IModuleTokenMinter(token).burn(_from, _amount);

        //pull from source
        IModule(staker).withdraw(lptoken, source, _amount);

        //return lp tokens
        IERC20(lptoken).safeTransfer(_to, _amount);

        emit Withdrawn(_to, _moduleId, _amount);
    }

    /// @notice Withdraw LP tokens
    /// @param _moduleId Module ID
    /// @param _amount Amount to withdraw
    function withdraw(uint256 _moduleId, uint256 _amount) public returns (bool) {
        _withdraw(_moduleId, _amount, msg.sender, msg.sender);
        return true;
    }

    /// @notice Withdraw all LP tokens
    /// @param _moduleId Module ID
    function withdrawAll(uint256 _moduleId) public returns (bool) {
        address token = modulePoolInfo[_moduleId].token;
        uint256 userBal = IERC20(token).balanceOf(msg.sender);
        withdraw(_moduleId, userBal);
        return true;
    }

    /// @notice Allow reward contracts to send here and withdraw to user
    /// @param _modulePoolId Module Pool Id
    /// @param _amount Amount
    /// @param _to To address
    function withdrawTo(uint256 _modulePoolId, uint256 _amount, address _to)
        external
        returns (bool)
    {
        address rewardContract = modulePoolInfo[_modulePoolId].rewards;
        require(msg.sender == rewardContract, "Must be RewardContract");

        _withdraw(_modulePoolId, _amount, msg.sender, _to);
        return true;
    }

    /// @notice Claim rewards
    /// @param _modulePoolId Module Pool Id
    /// @param _source Source
    function claimRewards(uint256 _modulePoolId, address _source) external returns (bool) {
        // TODO: this was prev for stash
        IModule(staker).claimRewards(_source);
        return true;
    }

    /// @notice Claim rewards and disperse to reward contracts
    /// @param _modulePoolId Module Pool Id
    function _earmarkRewards(uint256 _modulePoolId) internal {
        ModulePoolInfo storage modulePool = modulePoolInfo[_modulePoolId];

        address source = modulePool.source;
        address rewardToken = modulePool.rewardToken;

        // TODO: fill out remaining stub (need to get bal)
        // Also address fees / incentives per original method
        // Fetch the rewards for the given module pool's source

        uint256 rewardTokenBal = IERC20(rewardToken).balanceOf(address(this));

        address rewardContract = modulePool.rewards;
        IERC20(rewardToken).safeTransfer(rewardContract, rewardTokenBal);
        IModuleRewardPool(rewardContract).queueNewRewards(rewardTokenBal);
    }

    /// @notice Get rewards for given module pool
    /// @param _modulePoolId Module Pool Id
    function earmarkRewards(uint256 _modulePoolId) external returns (bool) {
        _earmarkRewards(_modulePoolId);
        return true;
    }

    /// @notice Claim rewards
    /// @param _modulePoolId Module Pool Id
    /// @param _address Recipient
    /// @param _amount Amount
    function rewardClaimed(uint256 _modulePoolId, address _address, uint256 _amount)
        external
        returns (bool)
    {
        address rewardContract = modulePoolInfo[_modulePoolId].rewards;
        require(msg.sender == rewardContract || msg.sender == lockRewards, "!auth");

        //mint reward tokens
        IModuleTokenMinter(minter).mint(_address, _amount);

        return true;
    }
}
