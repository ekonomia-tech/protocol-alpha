/// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@modules/cdpModule/ICDPPool.sol";
import "@oracle/ChainlinkPriceFeed.sol";
import "@protocol/interfaces/IModuleManager.sol";

/// @title CDPPool.sol
/// @notice Keeps track of collateral-specific user CDP and relevant CDP variables
/// @author Ekonomia

/*
    Short summary on how this module works:
    1. Upon deployment, there are a few parameters to be set:
        a. minDeb - the minimum debt to be taken in order to open a CDP
        b. liquidationCR - the CR is which a CDP becomes available from liquidation
        c. minCR - the minimum CR required to open a CDP. has to be higher than liquidationCR.
        d. protocolFee - currently set on constructor, but I want to change this to pull the protocol fee fro moduleManager
    2. The prices are all takes from chainlink price feeds
    3. Each CDPPool deals with only 1 type of collateral

    functions:
    1. open() - open a brand new CDP for a user. if there is already an open CDP, the user cannot call this function
    2. addCollateral() - the user can add collateral to the position, healing the CDP further. No fee
    3. removeCollateral() - the user can remove collateral from the position in case the CR goes higher. There is a fee
    4. addDebt() - the user can take additional debt if the CR approves it. in order to take more debt, minCR has to be met.
    5. removeDebt() - the user can remove debt, burning PHO from the user causing heal of the position. minDebt has to be met. No fee
    6. close() - If the user wants to completely close the position, he can call this function. this is the only function that closes the position.
    7. liquidate() - liquidation function in case the CR drops under the liquidationCR. currently does NOT handle underwater liquidations.
    
*/

contract CDPPool is ICDPPool {
    struct PoolBalance {
        uint256 collateral;
        uint256 pho;
    }

    struct CDP {
        uint256 debt;
        uint256 collateral;
    }

    IModuleManager public moduleManager;
    ChainlinkPriceFeed public priceOracle;
    IERC20Metadata public immutable collateral;

    uint256 private constant POINT_PRECISION = 10 ** 5;
    uint256 private constant PRICE_PRECISION = 10 ** 18;
    uint256 private constant LIQUIDATION_REWARD = 5000;
    /// 5%

    uint256 public minCR;
    //// minimum collateral ration to open a position
    uint256 public liquidationCR;
    //// collateral ratio liquidation threshold
    uint256 public minDebt;
    //// min debt to open a CDP
    uint256 public protocolFee;
    uint256 public earnedFees;

    PoolBalance public balance;

    mapping(address => CDP) public cdps;

    constructor(
        address _moduleManager,
        address _priceOracle,
        address _collateral,
        address _chainlinkPriceFeed,
        uint256 _minCR,
        uint256 _liquidationCR,
        uint256 _minDebt,
        uint256 _protocolFee
    ) {
        if (
            _moduleManager == address(0) || _priceOracle == address(0) || _collateral == address(0)
                || _chainlinkPriceFeed == address(0)
        ) {
            revert ZeroAddress();
        }

        if (_minCR <= 10 ** 5 || _minDebt == 0 || _protocolFee == 0 || _liquidationCR <= _minCR) {
            revert ValueNotInRange();
        }
        moduleManager = IModuleManager(_moduleManager);
        priceOracle = ChainlinkPriceFeed(_priceOracle);
        collateral = IERC20Metadata(_collateral);
        priceOracle.addFeed(_collateral, _chainlinkPriceFeed);
        minCR = _minCR;
        liquidationCR = _liquidationCR;
        minDebt = _minDebt;
        protocolFee = _protocolFee;
    }

    //// @notice Creates a new CDP and calculate all the relevant variables
    //// @param _collateralAmount The amount of collateral of the CDP
    //// @param _debtAmount The amount of debt to be taken
    function open(uint256 _collateralAmount, uint256 _debtAmount) external {
        if (_collateralAmount == 0 || _debtAmount == 0) revert ZeroValue();
        if (_debtAmount < minDebt) revert DebtTooLow();
        if (cdps[msg.sender].debt > 0) revert CDPAlreadyActive();

        uint256 cr = computeCR(_collateralAmount, _debtAmount);

        if (cr < minCR) revert CRTooLow();

        collateral.transferFrom(msg.sender, address(this), _collateralAmount);

        cdps[msg.sender] = CDP(_debtAmount, _collateralAmount);

        moduleManager.mintPHO(msg.sender, _debtAmount);

        balance.pho += _debtAmount;
        balance.collateral += _collateralAmount;

        emit Opened(msg.sender, _debtAmount, _collateralAmount);
    }

    //// @notice User deposits collateral to their CDP
    //// @dev Called by CDPManager.sol. Deposit is meant to top up CDP either to increase CR or ultimately take more debt
    //// @param _collateralAmount Amount of collateral to add to CDP
    function addCollateral(uint256 _collateralAmount) external {
        if (_collateralAmount == 0) revert ZeroValue();

        CDP storage cdp = cdps[msg.sender];

        if (cdp.debt == 0) revert CDPNotActive();

        uint256 updatedCollateral = cdp.collateral + _collateralAmount;
        uint256 newCR = computeCR(updatedCollateral, cdp.debt);

        collateral.transferFrom(msg.sender, address(this), _collateralAmount);

        cdp.collateral = updatedCollateral;
        balance.collateral += _collateralAmount;

        emit CollateralAdded(msg.sender, cdp.debt, cdp.collateral, newCR);
    }

    //// @notice User withdraws collateral from their CDP
    //// @dev This function can be called only when there is a debt in the CDP
    //// @param _collateralAmount The amount of collateral to remove
    function removeCollateral(uint256 _collateralAmount) external {
        if (_collateralAmount == 0) revert ZeroValue();

        CDP storage cdp = cdps[msg.sender];

        if (cdp.debt == 0) revert CDPNotActive();
        /// Calculate the protocol protocolFee to be prepared for any debt status ( debt > 0 or debt == 0)
        (uint256 fee, uint256 amountToTransfer) = calculateProtocolFee(_collateralAmount);

        uint256 debtInCollateral = debtToCollateral(cdp.debt);

        /// calculate the minimum required collateral to at least match the minimum required collateral to maintain an open CDP
        uint256 minRequiredCollateral = debtInCollateral * minCR / POINT_PRECISION;

        /// The amount of collateral that is permitted for withdrawal
        uint256 surplusCollateral = cdp.collateral - minRequiredCollateral;

        /// Check if the requested collateral to remove <= permitted collateral to withdraw
        if (surplusCollateral < _collateralAmount) revert RequestedAmountTooHigh();

        /// The CDP collateral after the removal of the wanted amount
        uint256 updatedCollateral = cdp.collateral - _collateralAmount;

        cdp.collateral = updatedCollateral;
        balance.collateral -= _collateralAmount;

        collateral.transfer(msg.sender, amountToTransfer);

        _accrueProtocolFees(fee);

        emit CollateralRemoved(msg.sender, _collateralAmount, cdp.collateral);
    }

    //// @notice User takes on more debt and is transferred newly minted $STABLE
    //// @param _debtAmount The amount of debt to add
    function addDebt(uint256 _debtAmount) external {
        if (_debtAmount == 0) revert ZeroValue();

        CDP storage cdp = cdps[msg.sender];

        if (cdp.debt == 0) revert CDPNotActive();

        uint256 updatedDebt = cdp.debt + _debtAmount;

        /// Check if the collateral worth of the total debt after the debt increase will suffice to cover the debt
        uint256 debtInCollateral = debtToCollateral(updatedDebt);

        /// Calculate the required collateral to maintain the minimum CR required to have an open position
        uint256 requiredCollateral = debtInCollateral * minCR / POINT_PRECISION;

        if (requiredCollateral > cdp.collateral) revert RequestedAmountTooHigh();

        moduleManager.mintPHO(msg.sender, _debtAmount);

        /// Accrue stablecoin debt to balance
        balance.pho += _debtAmount;

        cdp.debt = updatedDebt;

        emit DebtAdded(msg.sender, updatedDebt, cdp.collateral);
    }

    //// @notice Liquidates user CDP when CR < liquidateCR
    //// @param _user The user that is being liquidated
    function liquidate(address _user) external {
        CDP storage cdp = cdps[_user];

        if (cdp.debt == 0) revert CDPNotActive();

        /// Calculate the current CR of the position and validate the CDP is in liquidation zone
        uint256 cr = computeCR(cdp.collateral, cdp.debt);

        if (cr >= liquidationCR) revert NotInLiquidationZone();

        /// update pool balance
        balance.pho -= cdp.debt;
        balance.collateral -= cdp.collateral;

        /// Calculate the protocol protocolFee to be paid and the collateral left in the CDP after the protocolFee deduction
        (uint256 fee, uint256 collateralAfterFee) = calculateProtocolFee(cdp.collateral);

        /// Calculate the liquidation Fee
        uint256 liquidationFee = calculateLiquidationFee(collateralAfterFee);

        /// Calculate the exact collateral that corresponds the the debt
        uint256 debtInCollateral = debtToCollateral(cdp.debt);

        /// Calculate the total amount to be transferred to the liquidator
        uint256 liquidatorCollateralAmount = debtInCollateral + liquidationFee;

        /// Calculate the remainder of the collateral to transfer to the CDP owner
        uint256 repayToCDPOwner = collateralAfterFee - liquidatorCollateralAmount;

        /// Pay out the debt by the liquidator
        moduleManager.burnPHO(msg.sender, cdp.debt);

        /// Transfer the collateral to the liquidator
        collateral.transfer(msg.sender, liquidatorCollateralAmount);

        /// Transfer the remaining collateral to the cdpOwner if there is any
        if (repayToCDPOwner > 0) {
            collateral.transfer(_user, repayToCDPOwner);
        }

        emit Liquidate(
            _user, msg.sender, liquidatorCollateralAmount, cdp.debt, cdp.collateral, repayToCDPOwner
            );

        /// Accrue fees
        _accrueProtocolFees(fee);

        delete cdps[_user];
        emit Closed(_user);
    }

    //// @notice Remove debt from a cdp without closing it
    //// @param _debt The amount of debt the user wishes to remove
    function removeDebt(uint256 _debt) external {
        if (_debt == 0) revert ZeroValue();

        CDP storage cdp = cdps[msg.sender];
        if (cdp.debt == 0) revert CDPNotActive();
        if (cdp.debt - _debt < minDebt) revert RequestedAmountTooHigh();

        moduleManager.burnPHO(msg.sender, _debt);

        cdp.debt -= _debt;
        balance.pho -= _debt;

        emit DebtRemoved(msg.sender, cdp.debt, cdp.collateral);
    }

    //// @notice User closes their position by repaying the debt in full
    //// @param _debt The amount of debt user has to pay
    function close(uint256 _debt) external {
        if (_debt == 0) revert ZeroValue();

        CDP storage cdp = cdps[msg.sender];

        if (cdp.debt == 0) revert CDPNotActive();
        if (cdp.debt != _debt) revert FullAmountNotPresent();

        moduleManager.burnPHO(msg.sender, _debt);

        (uint256 fee, uint256 amountToTransfer) = calculateProtocolFee(cdp.collateral);
        balance.pho -= _debt;
        balance.collateral -= cdp.collateral;

        collateral.transfer(msg.sender, amountToTransfer);

        _accrueProtocolFees(fee);

        delete cdps[msg.sender];
        emit Closed(msg.sender);
    }

    //// @notice Get CR for respective CDP
    //// @dev Currently the price oracle returns 2000 * (10 ** 8)
    //// @param _collateralAmount Total collateral within respective CDP
    //// @param _debtAmount Total debt within respective CDP
    //// @return cr The resultant CR for the respective CDP
    function computeCR(uint256 _collateralAmount, uint256 _debtAmount)
        public
        view
        returns (uint256)
    {
        uint256 collateralUSD = collateralToUSD(_collateralAmount);
        return (collateralUSD * POINT_PRECISION) / _debtAmount;
    }

    function _getCollateralPrice() private view returns (uint256) {
        return priceOracle.getPrice(address(collateral));
    }

    //// @notice Calculates fee associated to respective protocol tx type
    //// @dev Protocol fee is called upon for open(), deposit(), withdraw(), liquidate(), redeem(), and repay(), and it only tracks collateral movement
    //// @param amount Respective amount used to calculate appropriate fee
    //// @return fee amount of fee in collateral taken by protocol
    //// @return remainder amount of collateral or debt used in respective tx
    function calculateProtocolFee(uint256 amount) public view returns (uint256, uint256) {
        uint256 fee = (amount * protocolFee) / POINT_PRECISION;
        uint256 remainder = amount - protocolFee;
        return (fee, remainder);
    }

    //// @notice Gets the fee paid out to liquidator per respective liquidation
    //// @return amount paid out to liquidator
    function calculateLiquidationFee(uint256 amount) public pure returns (uint256) {
        return (amount * LIQUIDATION_REWARD) / POINT_PRECISION;
    }

    //// @notice Accumulates protocol fees
    function _accrueProtocolFees(uint256 fee) private {
        earnedFees = earnedFees + fee;
    }

    //// @notice Converts debt into collateral for mathematical purposes
    //// @dev Currently the price oracle returns 2000 * (10 ** 8)
    //// @param _debt Amount to be converted
    //// @return debt in collateral units
    function debtToCollateral(uint256 _debt) public view returns (uint256) {
        uint256 collateralPrice = _getCollateralPrice();
        return _debt * (10 ** collateral.decimals()) / collateralPrice;
    }

    //// @notice Converts collateral into USD
    //// @param _amount Amount to convert
    //// @return amount converted to USD
    function collateralToUSD(uint256 _amount) public view returns (uint256) {
        uint256 collateralPrice = _getCollateralPrice();
        return _amount * collateralPrice / PRICE_PRECISION;
    }

    //// @notice Transfers `earnedFees` to
    function withdrawFees() external {
        /// TODO: implement this based on future decision as to here fees go
    }

    //// @notice Gets total pool collateral in USD
    //// @return result Total pool collateral converted to USD
    function getTotalNormalizedCollateral() public view returns (uint256) {
        return collateralToUSD(balance.collateral);
    }
}
