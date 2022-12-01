// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "../BaseSetup.t.sol";

contract TreasuryTest is BaseSetup {
    error Unauthorized();

    event WithdrawTo(address indexed user, uint256 amount);

    function setUp() public {
        _getUSDC(address(treasury), ONE_MILLION_D6);
        vm.deal(address(treasury), ONE_HUNDRED_D18);
    }

    /// withdrawTo()

    function testWithdrawTo(uint256 _amount) public {
        _amount = bound(_amount, 1, usdc.balanceOf(address(treasury)));

        uint256 treasuryBalanceBefore = usdc.balanceOf(address(treasury));

        vm.expectEmit(true, true, false, true);
        emit WithdrawTo(user1, _amount);
        vm.prank(TONGovernance);
        treasury.withdrawTo(IERC20(USDC_ADDRESS), _amount, user1);

        uint256 treasuryBalanceAfter = usdc.balanceOf(address(treasury));

        assertEq(treasuryBalanceAfter, treasuryBalanceBefore - _amount);
    }

    function testCannotWithdrawTokensUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        vm.prank(user1);
        treasury.withdrawTo(IERC20(USDC_ADDRESS), ONE_D6, user1);
    }

    /// execute()

    function testExecute() public {
        uint256 treasuryBalanceBefore = address(treasury).balance;
        uint256 treasuryStEthBalanceBefore = ERC20(STETH_ADDRESS).balanceOf(address(treasury));
        vm.prank(TONGovernance);
        (bool success,) = treasury.execute(
            STETH_ADDRESS, ONE_D18, abi.encodeWithSignature("submit(address)", ONE_D18)
        );

        uint256 treasuryBalanceAfter = address(treasury).balance;
        uint256 treasuryStEthBalanceAfter = ERC20(STETH_ADDRESS).balanceOf(address(treasury));

        assertApproxEqAbs(treasuryStEthBalanceAfter, treasuryStEthBalanceBefore + ONE_D18, 1 wei);
        assertEq(treasuryBalanceAfter, treasuryBalanceBefore - ONE_D18);
    }
}
