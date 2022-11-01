// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../interfaces/IModuleRewardFactory.sol";
import "./ModuleRewardPool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title ModuleRewardFactory
/// @notice Reward factory for modules
/// @author Ekonomia: https://github.com/Ekonomia
contract ModuleRewardFactory is IModuleRewardFactory {
    using Address for address;

    address public operator;
    mapping(address => bool) private rewardAccess;
    mapping(address => uint256[]) public rewardActiveList;

    constructor(address _operator) public {
        operator = _operator;
    }

    /// @notice Active reward count
    /// @param _reward reward
    function activeRewardCount(address _reward) external view returns (uint256) {
        return rewardActiveList[_reward].length;
    }

    /// @notice Add active reward
    /// @param _reward reward
    /// @param _modulePoolId module pool id
    function addActiveReward(address _reward, uint256 _modulePoolId) external returns (bool) {
        require(rewardAccess[msg.sender] == true, "Not authorized");
        if (_reward == address(0)) {
            return true;
        }

        uint256[] storage activeList = rewardActiveList[_reward];
        uint256 modulePoolId = _modulePoolId + 1; //offset by 1 so that we can use 0 as empty

        uint256 length = activeList.length;
        for (uint256 i = 0; i < length; i++) {
            if (activeList[i] == modulePoolId) return true;
        }
        activeList.push(modulePoolId);
        return true;
    }

    /// TODO: consolidate?
    /// @notice Remove active reward
    /// @param _reward reward
    /// @param _modulePoolId module pool id
    function removeActiveReward(address _reward, uint256 _modulePoolId) external returns (bool) {
        require(rewardAccess[msg.sender] == true, "Not authorized");
        if (_reward == address(0)) {
            return true;
        }

        uint256[] storage activeList = rewardActiveList[_reward];
        uint256 modulePoolId = _modulePoolId + 1; //offset by 1 so that we can use 0 as empty

        uint256 length = activeList.length;
        for (uint256 i = 0; i < length; i++) {
            if (activeList[i] == modulePoolId) {
                if (i != length - 1) {
                    activeList[i] = activeList[length - 1];
                }
                activeList.pop();
                break;
            }
        }
        return true;
    }

    /// @notice Create a Managed Reward Pool to handle distribution of all rewards for pool
    /// @param _modulePoolId module
    /// @param _depositToken deposit token
    /// @param _rewardToken reward token
    function createRewards(uint256 _modulePoolId, address _depositToken, address _rewardToken)
        external
        returns (address)
    {
        require(msg.sender == operator, "Must be operator");

        //operator = booster(deposit) contract so that new crv can be added and distributed
        //reward manager = this factory so that extra incentive tokens(ex. snx) can be linked to the main managed reward pool
        ModuleRewardPool rewardPool = new ModuleRewardPool(
            _modulePoolId,
            _depositToken,
            _rewardToken,
            operator,
            address(this)
        );
        return address(rewardPool);
    }

    /// TODO: consolidate
    //create a virtual balance reward pool that mimicks the balance of a pool's main reward contract
    //used for extra incentive tokens(ex. snx) as well as vecrv fees
    function createTokenRewards(address _token, address _mainRewards, address _operator)
        external
        returns (address)
    {
        // Not needed
    }
}
