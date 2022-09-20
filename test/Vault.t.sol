// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseSetup.t.sol";

// error Unauthorized();

contract VaultTest is BaseSetup {
    event CallerWhitelisted(address indexed caller);
    event CallerRevoked(address indexed caller);

    function setUp() public {
        _fundAndApproveUSDC(owner, address(dispatcher), tenThousand_d6, tenThousand_d6);
    }
    /// getVaultToken()

    function testGetVaultToken() public {
        assertEq(usdcVault.getVaultToken(), USDC_ADDRESS);
        assertEq(fraxVault.getVaultToken(), fraxAddress);
    }

    /// getTokenPriceUSD()

    function testGetTokenPriceUSD() public {
        assertEq(usdcVault.getTokenPriceUSD(), one_d6);
        assertEq(fraxVault.getTokenPriceUSD(), one_d6);
    }

    /// getVaultUSDValue()

    function testGetVaultUSDValue() public {
        uint256 usdcVaultBalanceBefore = usdc.balanceOf(address(usdcVault));

        _dispatchCollateralUSDC();

        uint256 usdcVaultBalanceAfter = usdc.balanceOf(address(usdcVault));

        assertEq(usdcVaultBalanceAfter, usdcVaultBalanceBefore + tenThousand_d6);
        assertEq(usdcVault.getVaultUSDValue(), tenThousand_d18);
    }

    /// provide()

    function testProvide() public {
        _dispatchCollateralUSDC();
        uint256 dispatcherUSDCBalanceBefore = usdc.balanceOf(address(dispatcher));
        uint256 vaultUSDCBalanceBefore = usdc.balanceOf(address(usdcVault));

        vm.prank(address(dispatcher));
        usdcVault.provide(oneThousand_d6);

        uint256 dispatcherUSDCBalanceAfter = usdc.balanceOf(address(dispatcher));
        uint256 vaultUSDCBalanceAfter = usdc.balanceOf(address(usdcVault));

        assertEq(dispatcherUSDCBalanceAfter, dispatcherUSDCBalanceBefore + oneThousand_d6);
        assertEq(vaultUSDCBalanceAfter, vaultUSDCBalanceBefore - oneThousand_d6);
    }

    function testCannotProvideZeroAmount() public {
        vm.expectRevert("Vault: zero amount detected");
        vm.prank(address(dispatcher));
        usdcVault.provide(0);
    }

    function testCannotProvideNotApproved() public {
        vm.expectRevert("Vault: caller not approved");
        vm.prank(user1);
        usdcVault.provide(oneThousand_d6);
    }

    function testCannotProvideNotEnoughCollateral() public {
        vm.expectRevert("Vault: not enough collateral");
        vm.prank(address(dispatcher));
        usdcVault.provide(oneThousand_d6);
    }

    /// whitelistCaller()

    function testWhitelistCaller() public {
        vm.expectEmit(true, false, false, true);
        emit CallerWhitelisted(address(103));
        vm.prank(owner);
        usdcVault.whitelistCaller(address(103));
        assertTrue(usdcVault.whitelist(address(103)));
    }

    function testCannotWhitelistCallerNotAllowed() public {
        vm.expectRevert("Ownable: caller is not the owner");
        usdcVault.whitelistCaller(address(103));
    }

    function testCannotWhitelistCallerAddressZero() public {
        vm.expectRevert("Vault: zero address detected");
        vm.prank(owner);
        usdcVault.whitelistCaller(address(0));
    }

    function testCannotWhitelistCallerAlreadyApproved() public {
        vm.expectRevert("Vault: caller is already approved");
        vm.prank(owner);
        usdcVault.whitelistCaller(address(dispatcher));
    }

    /// revokeCaller()

    function testRevokeCaller() public {
        vm.expectEmit(true, false, false, true);
        emit CallerRevoked(address(dispatcher));
        vm.prank(owner);
        usdcVault.revokeCaller(address(dispatcher));
        assertFalse(usdcVault.whitelist(address(dispatcher)));
    }

    function testCannotRevokeCallerNotAllowed() public {
        vm.expectRevert("Ownable: caller is not the owner");
        usdcVault.revokeCaller(address(103));
    }

    function testCannotRevokeCallerAddressZero() public {
        vm.expectRevert("Vault: zero address detected");
        vm.prank(owner);
        usdcVault.revokeCaller(address(0));
    }

    function testCannotRevokeCallerNotApproved() public {
        vm.expectRevert("Vault: caller is not approved");
        vm.prank(owner);
        usdcVault.revokeCaller(user1);
    }

    /// internal functions

    function _dispatchCollateralUSDC() internal {
        vm.prank(owner);
        dispatcher.dispatchCollateral(USDC_ADDRESS, tenThousand_d6, tenThousand_d6);
    }
}
