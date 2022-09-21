// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseSetup.t.sol";
import "src/contracts/Vault.sol";

contract DispatcherTest is BaseSetup {
    event TellerUpdated(address indexed tellerAddress);
    event VaultAdded(address indexed vault);
    event VaultRemoved(address indexed vault);
    event Dispatched(
        address indexed user, address indexed collateralToken, uint256 collateralIn, uint256 phoOut
    );
    event Redeemed(
        address indexed user, address indexed collateralToken, uint256 phoIn, uint256 collateralOut
    );

    /// dispatchCollateral()

    function testDispatchCollateralUSDC() public {
        _fundAndApproveUSDC(user1, address(dispatcher), tenThousand_d6 * 2, tenThousand_d6);

        address tokenIn = USDC_ADDRESS;
        uint256 amountIn = tenThousand_d6;
        uint256 minPHOOut = tenThousand_d18 * 99 / 100;

        uint256 usdcVaultBalanceBefore = usdc.balanceOf(address(usdcVault));
        uint256 user1USDCBalanceBefore = usdc.balanceOf(user1);
        uint256 user1PHOBalanceBefore = pho.balanceOf(user1);
        uint256 tellerDispatcherMintBalanceBefore = teller.mintingBalances(address(dispatcher));

        vm.expectEmit(true, true, false, true);
        emit Dispatched(user1, USDC_ADDRESS, amountIn, tenThousand_d18);
        vm.prank(user1);
        dispatcher.dispatchCollateral(USDC_ADDRESS, amountIn, minPHOOut);

        uint256 usdcVaultBalanceAfter = usdc.balanceOf(address(usdcVault));
        uint256 user1USDCBalanceAfter = usdc.balanceOf(user1);
        uint256 user1PHOBalanceAfter = pho.balanceOf(user1);
        uint256 tellerDispatcherMintBalanceAfter = teller.mintingBalances(address(dispatcher));

        assertEq(usdcVaultBalanceAfter, usdcVaultBalanceBefore + amountIn);
        assertEq(user1USDCBalanceAfter, user1USDCBalanceBefore - amountIn);
        assertEq(user1PHOBalanceAfter, user1PHOBalanceBefore + tenThousand_d18);
        assertEq(
            tellerDispatcherMintBalanceAfter, tellerDispatcherMintBalanceBefore + tenThousand_d18
        );
    }

    function testDispatchCollateralFRAX() public {
        vm.prank(fraxRichGuy);
        frax.transfer(user1, tenThousand_d18);

        vm.prank(user1);
        frax.approve(address(dispatcher), tenThousand_d18);

        address tokenIn = fraxAddress;
        uint256 amountIn = tenThousand_d18;
        uint256 minPHOOut = tenThousand_d18 * 99 / 100;

        uint256 fraxVaultBalanceBefore = frax.balanceOf(address(fraxVault));
        uint256 user1FRAXBalanceBefore = frax.balanceOf(user1);
        uint256 user1PHOBalanceBefore = pho.balanceOf(user1);
        uint256 tellerDispatcherMintBalanceBefore = teller.mintingBalances(address(dispatcher));

        vm.expectEmit(true, true, false, true);
        emit Dispatched(user1, fraxAddress, amountIn, tenThousand_d18);
        vm.prank(user1);
        dispatcher.dispatchCollateral(fraxAddress, amountIn, minPHOOut);

        uint256 fraxVaultBalanceAfter = frax.balanceOf(address(fraxVault));
        uint256 user1FRAXBalanceAfter = frax.balanceOf(user1);
        uint256 user1PHOBalanceAfter = pho.balanceOf(user1);
        uint256 tellerDispatcherMintBalanceAfter = teller.mintingBalances(address(dispatcher));

        assertEq(fraxVaultBalanceAfter, fraxVaultBalanceBefore + amountIn);
        assertEq(user1FRAXBalanceAfter, user1FRAXBalanceBefore - amountIn);
        assertEq(user1PHOBalanceAfter, user1PHOBalanceBefore + tenThousand_d18);
        assertEq(
            tellerDispatcherMintBalanceAfter, tellerDispatcherMintBalanceBefore + tenThousand_d18
        );
    }

    function testCannotDispatchCollateralZeroAddress() public {
        vm.expectRevert("Dispatcher: zero address detected");
        dispatcher.dispatchCollateral(address(0), tenThousand_d18, tenThousand_d18);
    }

    function testCannotDispatchCollateralZeroValue() public {
        vm.expectRevert("Dispatcher: zero value detected");
        dispatcher.dispatchCollateral(USDC_ADDRESS, 0, 0);
    }

    function testCannotDispatchCollateralTokenNotAccepted() public {
        vm.expectRevert("Dispatcher: token not accepted");
        dispatcher.dispatchCollateral(fraxBPLPToken, tenThousand_d18, tenThousand_d18);
    }

    function testCannotDispatchCollateralSlippageReached() public {
        priceOracle.setUSDCUSDPrice(980000);
        vm.expectRevert("Dispatcher: max slippage reached");

        vm.prank(user1);
        dispatcher.dispatchCollateral(USDC_ADDRESS, tenThousand_d6, tenThousand_d18);
    }

    /// redeemPHO()

    function testRedeemPHOForUSDC() public {
        // mint PHO for USDC for user1
        testDispatchCollateralUSDC();

        uint256 phoIn = tenThousand_d18;
        uint256 minCollateralOut = tenThousand_d6 * 99 / 100;

        vm.prank(user1);
        pho.approve(address(dispatcher), tenThousand_d18);

        uint256 usdcVaultBalanceBefore = usdc.balanceOf(address(usdcVault));
        uint256 user1USDCBalanceBefore = usdc.balanceOf(user1);
        uint256 user1PHOBalanceBefore = pho.balanceOf(user1);

        vm.expectEmit(true, true, false, true);
        emit Redeemed(user1, USDC_ADDRESS, phoIn, tenThousand_d6);
        vm.prank(user1);
        dispatcher.redeemPHO(USDC_ADDRESS, tenThousand_d18, minCollateralOut);

        uint256 usdcVaultBalanceAfter = usdc.balanceOf(address(usdcVault));
        uint256 user1USDCBalanceAfter = usdc.balanceOf(user1);
        uint256 user1PHOBalanceAfter = pho.balanceOf(user1);

        assertEq(usdcVaultBalanceAfter, usdcVaultBalanceBefore - tenThousand_d6);
        assertEq(user1USDCBalanceAfter, user1USDCBalanceBefore + tenThousand_d6);
        assertEq(user1PHOBalanceAfter, user1PHOBalanceBefore - tenThousand_d18);
    }

    function testRedeemPHOForFRAX() public {
        // mint PHO for USDC for user1
        testDispatchCollateralFRAX();

        uint256 phoIn = tenThousand_d18;
        uint256 minCollateralOut = tenThousand_d18 * 99 / 100;

        vm.prank(user1);
        pho.approve(address(dispatcher), tenThousand_d18);

        uint256 fraxVaultBalanceBefore = frax.balanceOf(address(fraxVault));
        uint256 user1FRAXBalanceBefore = frax.balanceOf(user1);
        uint256 user1PHOBalanceBefore = pho.balanceOf(user1);

        vm.expectEmit(true, true, false, true);
        emit Redeemed(user1, fraxAddress, phoIn, tenThousand_d18);
        vm.prank(user1);
        dispatcher.redeemPHO(fraxAddress, tenThousand_d18, minCollateralOut);

        uint256 fraxVaultBalanceAfter = frax.balanceOf(address(fraxVault));
        uint256 user1FRAXBalanceAfter = frax.balanceOf(user1);
        uint256 user1PHOBalanceAfter = pho.balanceOf(user1);

        assertEq(fraxVaultBalanceAfter, fraxVaultBalanceBefore - tenThousand_d18);
        assertEq(user1FRAXBalanceAfter, user1FRAXBalanceBefore + tenThousand_d18);
        assertEq(user1PHOBalanceAfter, user1PHOBalanceBefore - tenThousand_d18);
    }

    function testCannotRedeemPHOZeroAddress() public {
        vm.expectRevert("Dispatcher: zero address detected");
        dispatcher.redeemPHO(address(0), tenThousand_d18, tenThousand_d6);
    }

    function testCannotRedeemPHOZeroValue() public {
        vm.expectRevert("Dispatcher: zero value detected");
        dispatcher.redeemPHO(USDC_ADDRESS, 0, 0);
    }

    function testCannotRedeemPHOTokenNotAccepted() public {
        vm.expectRevert("Dispatcher: token not accepted");
        dispatcher.redeemPHO(fraxBPLPToken, tenThousand_d18, tenThousand_d18);
    }

    function testCannotRedeemPHOVaultTooLow() public {
        vm.expectRevert("Dispatcher: vault too low");
        vm.prank(user1);
        dispatcher.redeemPHO(USDC_ADDRESS, tenThousand_d18, tenThousand_d6);
    }

    function testCannotRedeemPHOSlippageReached() public {
        testDispatchCollateralUSDC();

        priceOracle.setUSDCUSDPrice(1020000);
        vm.expectRevert("Dispatcher: max slippage reached");

        vm.prank(user1);
        dispatcher.redeemPHO(USDC_ADDRESS, tenThousand_d18, tenThousand_d6);
    }

    /// addVault()

    function testAddVault() public {
        vm.prank(owner);
        dispatcher.removeVault(address(fraxVault));
        assertTrue(dispatcher.vaults(fraxAddress) == address(0));

        vm.expectEmit(true, false, false, true);
        emit VaultAdded(address(fraxVault));
        vm.prank(owner);
        dispatcher.addVault(address(fraxVault));

        assertTrue(dispatcher.vaults(fraxAddress) == address(fraxVault));
    }

    function testCannotAddVaultZeroAddress() public {
        vm.expectRevert("Dispatcher: zero address detected");
        vm.prank(owner);
        dispatcher.addVault(address(0));
    }

    function testCannotAddVaultNotAllowed() public {
        vm.expectRevert("Ownable: caller is not the owner");
        dispatcher.addVault(address(101));
    }

    function testCannotAddVaultAlreadyAdded() public {
        vm.expectRevert("Dispatcher: vault already added");
        vm.prank(owner);
        dispatcher.addVault(address(usdcVault));
    }

    /// removeVault()

    function testRemoveVault() public {
        vm.expectEmit(true, false, false, true);
        emit VaultRemoved(address(usdcVault));
        vm.prank(owner);
        dispatcher.removeVault(address(usdcVault));

        assertTrue(dispatcher.vaults(USDC_ADDRESS) == address(0));
    }

    function testCannotRemoveVaultZeroAddress() public {
        vm.expectRevert("Dispatcher: zero address detected");
        vm.prank(owner);
        dispatcher.removeVault(address(0));
    }

    function testCannotRemoveVaultNotAllowed() public {
        vm.expectRevert("Ownable: caller is not the owner");
        dispatcher.removeVault(address(101));
    }

    function testCannotRemoveVaultNotRegistered() public {
        testRemoveVault();
        vm.expectRevert("Dispatcher: vault not registered");
        vm.prank(owner);
        dispatcher.removeVault(address(usdcVault));
    }

    /// setTeller()

    function setTeller() public {
        vm.startPrank(owner);
        address initialTeller = address(dispatcher.teller());
        vm.expectEmit(true, false, false, true);
        emit TellerUpdated(owner);
        dispatcher.setTeller(owner);

        assertTrue(initialTeller != address(dispatcher.teller()));
        assertEq(address(dispatcher.teller()), owner);
        vm.stopPrank();
    }

    function testCannotSetTellerAddressZero() public {
        vm.expectRevert("Dispatcher: zero address detected");
        vm.prank(owner);
        dispatcher.setTeller(address(0));
    }

    function testCannotSetTellerNotAllowed() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(user1);
        dispatcher.setTeller(address(0));
    }

    function testCannotSetTellerSameAddress() public {
        address currentTeller = address(dispatcher.teller());
        vm.expectRevert("Dispatcher: same address detected");
        vm.prank(owner);
        dispatcher.setTeller(currentTeller);
    }
}
