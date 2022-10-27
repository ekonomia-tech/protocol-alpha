// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

interface ICDPPool {
    error ZeroAddress();
    error ZeroValue();
    error ValueNotInRange();
    error DebtTooLow();
    error CRTooLow();
    error CDPNotActive();
    error CDPAlreadyActive();
    error RequestedAmountTooHigh();
    error FullAmountNotPresent();
    error NotInLiquidationZone();

    /// @notice Event emitted when a CDP is opened
    /// @param user The user that opens the CDP
    /// @param debt The debt in stablecoin
    /// @param collateral the collateral amount that was put in the protocol
    event Opened(address indexed user, uint256 debt, uint256 collateral);
    event CollateralAdded(address indexed user, uint256 debt, uint256 collateral, uint256 cr);
    event CollateralRemoved(
        address indexed user, uint256 removedCollateral, uint256 collateralLeft
    );
    event DebtAdded(address indexed user, uint256 debt, uint256 collateral);
    event DebtRemoved(address indexed user, uint256 debt, uint256 collateral);
    event Closed(address indexed user);

    /// @notice Event emitted when a liquidation is happening
    /// @param user The user being liquidated
    /// @param liquidator The user that is performing the liquidation
    /// @param paidToLiquidator The amount paid to Liquidator
    /// @param debt The amount of debt to be covered
    /// @param collateralLiquidated The amount of deb in collateral
    /// @param repaidToDebtor The amount repaid to original CDP owner
    event Liquidate(
        address indexed user,
        address indexed liquidator,
        uint256 paidToLiquidator,
        uint256 debt,
        uint256 collateralLiquidated,
        uint256 repaidToDebtor
    );

    /// @notice Transfers accrued earned fees to CDPManager
    /// @param amountWithdrawn Amount of earned fees withdrawn
    event WithdrawFees(uint256 amountWithdrawn);

    function open(uint256 _collateralAmount, uint256 _debtAmount) external;
    function addCollateral(uint256 _collateralAmount) external;
    function removeCollateral(uint256 _collateralAmount) external;
    function addDebt(uint256 _debtAmount) external;
    function removeDebt(uint256 _debtAmount) external;
    function liquidate(address _user) external;
    function withdrawFees() external;
    function getTotalNormalizedCollateral() external view returns (uint256);
}
