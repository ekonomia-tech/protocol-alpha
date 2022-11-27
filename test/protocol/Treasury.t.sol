// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "../BaseSetup.t.sol";

contract TreasuryTest is BaseSetup {
    error ZeroAddress();
    error ZeroValue();
    error Unauthorized();

    event Withdrawn(address indexed to, address indexed asset, uint256 amount);

    function setUp() public {
        _getUSDC(address(treasury), ONE_MILLION_D6);
        vm.deal(address(treasury), ONE_HUNDRED_D18);
    }

    /// withdrawTokens()

    function testWithdrawTokens(uint256 _amount) public {
        _amount = bound(_amount, 1, usdc.balanceOf(address(treasury)));

        uint256 treasuryBalanceBefore = usdc.balanceOf(address(treasury));

        vm.expectEmit(true, true, false, true);
        emit Withdrawn(user1, USDC_ADDRESS, _amount);
        vm.prank(TONGovernance);
        treasury.withdrawTokens(user1, USDC_ADDRESS, _amount);

        uint256 treasuryBalanceAfter = usdc.balanceOf(address(treasury));

        assertEq(treasuryBalanceAfter, treasuryBalanceBefore - _amount);
    }

    function testCannotWithdrawTokensUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        vm.prank(user1);
        treasury.withdrawTokens(user1, USDC_ADDRESS, ONE_D6);
    }

    function testCannotWithdrawTokensZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroAddress.selector));
        vm.prank(TONGovernance);
        treasury.withdrawTokens(address(0), USDC_ADDRESS, ONE_D6);

        vm.expectRevert(abi.encodeWithSelector(ZeroAddress.selector));
        vm.prank(TONGovernance);
        treasury.withdrawTokens(user1, address(0), ONE_D6);
    }

    function testCannotWithdrawTokensZeroValue() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroValue.selector));
        vm.prank(TONGovernance);
        treasury.withdrawTokens(user1, USDC_ADDRESS, 0);
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

    function testCannotExecuteZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroAddress.selector));
        vm.prank(TONGovernance);
        treasury.execute(address(0), ONE_D18, abi.encodeWithSignature("submit(address)", ONE_D18));
    }

    function testCannotExecuteZeroValue() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroValue.selector));
        vm.prank(TONGovernance);
        treasury.execute(STETH_ADDRESS, 0, abi.encodeWithSignature("submit(address)", 0));
    }
}
