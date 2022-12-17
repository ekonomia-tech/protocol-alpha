/// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@modules/cdpModule/ICDPPool.sol";
import "@oracle/IPriceOracle.sol";
import "@protocol/interfaces/IModuleManager.sol";
import "@modules/interfaces/IModuleAMO.sol";

/// @title CDPPool.sol
/// @notice Keeps track of collateral-specific user CDP and relevant CDP variables
/// @author Ekonomia

contract CDPPool is ICDPPool {
    struct PoolBalances {
        uint256 debt;
        uint256 collateral;
    }

    struct CDP {
        uint256 debt;
        uint256 collateral;
    }

    IModuleManager public moduleManager;
    IPriceOracle public priceOracle;
    IERC20Metadata public immutable collateral;

    uint256 private constant MAX_PPH = 10 ** 5;
    uint256 private constant ORACLE_PRICE_PRECISION = 10 ** 18;

    /// liquidation reward. In PPH (100000 = 100%)
    uint256 private constant LIQUIDATION_REWARD = 5000;

    /// minimum collateral ratio to open a position. . In PPH (100000 = 100%)
    uint256 public minCR;

    /// collateral ratio liquidation threshold. In PPH (100000 = 100%)
    uint256 public liquidationCR;

    /// protocol fee charged. In PPH (100000 = 100%)
    uint256 public minDebt;
    uint256 public protocolFee;
    uint256 public feesCollected;

    address public TONTimelock;

    PoolBalances public pool;

    mapping(address => CDP) public cdps;

    modifier onlyTONTimelock() {
        if (msg.sender != TONTimelock) revert NotTONTimelock();
        _;
    }

    constructor(
        address _moduleManager,
        address _priceOracle,
        address _collateral,
        address _TONTimelock,
        uint256 _minCR,
        uint256 _liquidationCR,
        uint256 _minDebt,
        uint256 _protocolFee
    ) {
        if (
            _moduleManager == address(0) || _priceOracle == address(0) || _collateral == address(0)
                || _TONTimelock == address(0)
        ) {
            revert ZeroAddress();
        }

        if (_minCR <= 10 ** 5 || _protocolFee > MAX_PPH || _liquidationCR >= _minCR) {
            revert ValueNotInRange();
        }

        if (_minDebt == 0 || _protocolFee == 0) revert ZeroValue();

        moduleManager = IModuleManager(_moduleManager);
        priceOracle = IPriceOracle(_priceOracle);
        collateral = IERC20Metadata(_collateral);
        TONTimelock = _TONTimelock;
        minCR = _minCR;
        liquidationCR = _liquidationCR;
        minDebt = _minDebt;
        protocolFee = _protocolFee;
    }

    /// @notice External function for _open()
    /// @param _collateralAmount The amount of collateral of the CDP
    /// @param _debtAmount The amount of debt to be taken
    function open(uint256 _collateralAmount, uint256 _debtAmount) external {
        return _open(msg.sender, msg.sender, _collateralAmount, _debtAmount);
    }

    /// @notice External function for _open() to be called on behalf of user
    /// @param _depositor the user that deposits the funds
    /// @param _user the user to open the CDP on behalf of
    /// @param _collateralAmount The amount of collateral of the CDP
    /// @param _debtAmount The amount of debt to be taken
    function openFor(
        address _depositor,
        address _user,
        uint256 _collateralAmount,
        uint256 _debtAmount
    ) external {
        return _open(_depositor, _user, _collateralAmount, _debtAmount);
    }

    /// @notice Creates a new CDP and calculate all the relevant variables
    /// @param _collateralAmount The amount of collateral of the CDP
    /// @param _debtAmount The amount of debt to be taken
    function _open(
        address _depositor,
        address _user,
        uint256 _collateralAmount,
        uint256 _debtAmount
    ) private {
        if (_user == address(0) || _depositor == address(0)) revert ZeroAddress();
        if (_collateralAmount == 0 || _debtAmount == 0) revert ZeroValue();
        if (_debtAmount < minDebt) revert DebtTooLow();
        if (cdps[_user].debt > 0) revert CDPAlreadyActive();

        uint256 cr = computeCR(_collateralAmount, _debtAmount);

        if (cr < minCR) revert CRTooLow();

        collateral.transferFrom(_depositor, address(this), _collateralAmount);

        cdps[_user] = CDP(_debtAmount, _collateralAmount);

        moduleManager.mintPHO(_user, _debtAmount);

        pool.debt += _debtAmount;
        pool.collateral += _collateralAmount;

        emit Opened(_user, _debtAmount, _collateralAmount);
    }

    /// @notice External function for _addCollateral()
    /// @param _collateralAmount Amount of collateral to add to CDP
    function addCollateral(uint256 _collateralAmount) external {
        return _addCollateral(msg.sender, msg.sender, _collateralAmount);
    }

    /// @notice External function for _addCollateral() to be called on behalf of user
    /// @param _depositor the user that deposits the funds
    /// @param _user the cdp owner
    /// @param _collateralAmount Amount of collateral to add to CDP
    function addCollateralFor(address _depositor, address _user, uint256 _collateralAmount)
        external
    {
        return _addCollateral(_depositor, _user, _collateralAmount);
    }

    /// @notice User deposits collateral to their CDP
    /// @param _depositor the user that deposits the funds
    /// @param _user the cdp owner
    /// @param _collateralAmount Amount of collateral to add to CDP
    function _addCollateral(address _depositor, address _user, uint256 _collateralAmount) private {
        if (_user == address(0) || _depositor == address(0)) revert ZeroAddress();
        if (_collateralAmount == 0) revert ZeroValue();

        CDP storage cdp = cdps[_user];

        if (cdp.debt == 0) revert CDPNotActive();

        uint256 updatedCollateral = cdp.collateral + _collateralAmount;

        collateral.transferFrom(_depositor, address(this), _collateralAmount);

        cdp.collateral = updatedCollateral;
        pool.collateral += _collateralAmount;

        emit CollateralAdded(_user, _collateralAmount, cdp.collateral);
    }

    /// @notice external function for _removeCollateral()
    /// @dev This function can be called only when there is a debt in the CDP
    /// @param _collateralAmount The amount of collateral to remove
    function removeCollateral(uint256 _collateralAmount) external {
        return _removeCollateral(msg.sender, _collateralAmount);
    }

    /// @notice external function for _removeCollateral() on behalf of user
    /// @dev This function can be called only when there is a debt in the CDP
    /// @param _user the cdp owner
    /// @param _collateralAmount The amount of collateral to remove
    function removeCollateralFor(address _user, uint256 _collateralAmount) external {
        return _removeCollateral(_user, _collateralAmount);
    }

    /// @notice User withdraws collateral from their CDP
    /// @dev This function can be called only when there is a debt in the CDP
    /// @param _collateralAmount The amount of collateral to remove
    function _removeCollateral(address _user, uint256 _collateralAmount) private {
        if (_user == address(0)) revert ZeroAddress();
        if (_collateralAmount == 0) revert ZeroValue();

        CDP storage cdp = cdps[_user];

        if (cdp.debt == 0) revert CDPNotActive();

        /// The CDP collateral after the removal of the wanted amount
        uint256 updatedCollateral = cdp.collateral - _collateralAmount;

        uint256 cr = computeCR(updatedCollateral, cdp.debt);

        if (cr < minCR) revert CRTooLow();

        cdp.collateral = updatedCollateral;
        pool.collateral -= _collateralAmount;

        collateral.transfer(_user, _collateralAmount);

        emit CollateralRemoved(_user, _collateralAmount, cdp.collateral);
    }

    /// @notice User takes on more debt and is transferred newly minted $STABLE
    /// @param _debtAmount The amount of debt to add
    function addDebt(uint256 _debtAmount) external {
        if (_debtAmount == 0) revert ZeroValue();

        CDP storage cdp = cdps[msg.sender];

        if (cdp.debt == 0) revert CDPNotActive();

        uint256 updatedDebt = cdp.debt + _debtAmount;

        uint256 cr = computeCR(cdp.collateral, updatedDebt);

        if (cr < minCR) revert CRTooLow();

        moduleManager.mintPHO(msg.sender, _debtAmount);

        /// Accrue stablecoin debt to pool
        pool.debt += _debtAmount;

        cdp.debt = updatedDebt;

        emit DebtAdded(msg.sender, _debtAmount, cdp.debt);
    }

    /// @notice Liquidates user CDP when CR < liquidateCR
    /// @dev Currently does not handle underwater liquidations
    /// @param _user The user that is being liquidated
    function liquidate(address _user) external {
        CDP storage cdp = cdps[_user];

        if (cdp.debt == 0) revert CDPNotActive();

        /// Calculate the current CR of the position and validate the CDP is in liquidation zone
        uint256 cr = computeCR(cdp.collateral, cdp.debt);

        if (cr >= liquidationCR) revert NotInLiquidationZone();

        /// update pool pool
        pool.debt -= cdp.debt;
        pool.collateral -= cdp.collateral;

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

        emit Liquidated(
            _user, msg.sender, liquidatorCollateralAmount, cdp.debt, cdp.collateral, repayToCDPOwner
            );

        /// Accrue fees
        _accrueProtocolFees(fee);

        delete cdps[_user];
        emit Closed(_user);
    }

    /// @notice Remove debt from a cdp without closing it
    /// @param _debt The amount of debt the user wishes to remove
    function removeDebt(uint256 _debt) external {
        if (_debt == 0) revert ZeroValue();

        CDP storage cdp = cdps[msg.sender];
        if (cdp.debt == 0) revert CDPNotActive();
        if (cdp.debt - _debt < minDebt) revert MinDebtNotMet();

        (uint256 fee,) = calculateProtocolFee(_debt);
        uint256 feeInCollateral = debtToCollateral(fee);

        moduleManager.burnPHO(msg.sender, _debt);

        cdp.debt -= _debt;
        cdp.collateral -= feeInCollateral;
        pool.debt -= _debt;
        pool.collateral -= feeInCollateral;

        _accrueProtocolFees(feeInCollateral);

        emit DebtRemoved(msg.sender, _debt, cdp.debt);
    }

    /// @notice User closes their position by repaying the debt in full
    function close() external {
        CDP storage cdp = cdps[msg.sender];

        if (cdp.debt == 0) revert CDPNotActive();

        moduleManager.burnPHO(msg.sender, cdp.debt);

        (uint256 fee,) = calculateProtocolFee(cdp.debt);
        uint256 feeInCollateral = debtToCollateral(fee);

        pool.debt -= cdp.debt;
        pool.collateral -= cdp.collateral;

        collateral.transfer(msg.sender, cdp.collateral - feeInCollateral);

        _accrueProtocolFees(feeInCollateral);

        delete cdps[msg.sender];
        emit Closed(msg.sender);
    }

    /// @notice Get CR for respective CDP
    /// @dev Currently the price oracle returns 2000 * (10 ** 8)
    /// @param _collateralAmount Total collateral within respective CDP
    /// @param _debtAmount Total debt within respective CDP
    /// @return cr The resultant CR for the respective CDP
    function computeCR(uint256 _collateralAmount, uint256 _debtAmount)
        public
        view
        returns (uint256)
    {
        uint256 collateralUSD = collateralToUSD(_collateralAmount);
        return (collateralUSD * MAX_PPH) / _debtAmount;
    }

    function _getCollateralPrice() private view returns (uint256) {
        return priceOracle.getPrice(address(collateral));
    }

    /// @notice Calculates fee associated to respective protocol tx type
    /// @dev Protocol fee is called upon for open(), deposit(), withdraw(), liquidate(), redeem(), and repay(), and it only tracks collateral movement
    /// @param amount Respective amount used to calculate appropriate fee
    /// @return fee amount of fee in collateral taken by protocol
    /// @return remainder amount of collateral or debt used in respective tx
    function calculateProtocolFee(uint256 amount) public view returns (uint256, uint256) {
        uint256 fee = (amount * protocolFee) / MAX_PPH;
        uint256 remainder = amount - fee;
        return (fee, remainder);
    }

    /// @notice Gets the fee paid out to liquidator per respective liquidation
    /// @return amount paid out to liquidator
    function calculateLiquidationFee(uint256 amount) public pure returns (uint256) {
        return (amount * LIQUIDATION_REWARD) / MAX_PPH;
    }

    /// @notice Accumulates protocol fees
    function _accrueProtocolFees(uint256 fee) private {
        feesCollected = feesCollected + fee;
    }

    /// @notice Converts debt into collateral for mathematical purposes
    /// @dev Currently the price oracle returns 2000 * (10 ** 8)
    /// @param _debt Amount to be converted
    /// @return debt in collateral units
    function debtToCollateral(uint256 _debt) public view returns (uint256) {
        uint256 collateralPrice = _getCollateralPrice();
        return _debt * (10 ** collateral.decimals()) / collateralPrice;
    }

    /// @notice Converts collateral into USD
    /// @param _amount Amount to convert
    /// @return amount converted to USD
    function collateralToUSD(uint256 _amount) public view returns (uint256) {
        uint256 collateralPrice = _getCollateralPrice();
        return _amount * collateralPrice / ORACLE_PRICE_PRECISION;
    }

    /// @notice Transfers `feesCollected` to
    function withdrawFees() external {
        /// TODO: implement this based on future decision as to here fees go
    }

    /// @notice Gets total pool collateral in USD
    /// @return result Total pool collateral converted to USD
    function getCollateralUSDTotal() public view returns (uint256) {
        return collateralToUSD(pool.collateral);
    }
}
