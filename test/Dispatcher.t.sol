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
        _fundAndApproveUSDC(user1, address(dispatcher), TEN_THOUSAND_D6 * 2, TEN_THOUSAND_D6);

        address tokenIn = USDC_ADDRESS;
        uint256 amountIn = TEN_THOUSAND_D6;
        uint256 minPHOOut = TEN_THOUSAND_D18 * 99 / 100;

        uint256 usdcVaultBalanceBefore = usdc.balanceOf(address(usdcVault));
        uint256 user1USDCBalanceBefore = usdc.balanceOf(user1);
        uint256 user1PHOBalanceBefore = pho.balanceOf(user1);
        uint256 tellerDispatcherMintBalanceBefore = teller.mintingBalances(address(dispatcher));

        vm.expectEmit(true, true, false, true);
        emit Dispatched(user1, USDC_ADDRESS, amountIn, TEN_THOUSAND_D18);
        vm.prank(user1);
        dispatcher.dispatchCollateral(USDC_ADDRESS, amountIn, minPHOOut);

        uint256 usdcVaultBalanceAfter = usdc.balanceOf(address(usdcVault));
        uint256 user1USDCBalanceAfter = usdc.balanceOf(user1);
        uint256 user1PHOBalanceAfter = pho.balanceOf(user1);
        uint256 tellerDispatcherMintBalanceAfter = teller.mintingBalances(address(dispatcher));

        assertEq(usdcVaultBalanceAfter, usdcVaultBalanceBefore + amountIn);
        assertEq(user1USDCBalanceAfter, user1USDCBalanceBefore - amountIn);
        assertEq(user1PHOBalanceAfter, user1PHOBalanceBefore + TEN_THOUSAND_D18);
        assertEq(
            tellerDispatcherMintBalanceAfter, tellerDispatcherMintBalanceBefore + TEN_THOUSAND_D18
        );
    }

    function testDispatchCollateralFRAX() public {
        vm.prank(fraxRichGuy);
        frax.transfer(user1, TEN_THOUSAND_D18);

        vm.prank(user1);
        frax.approve(address(dispatcher), TEN_THOUSAND_D18);

        address tokenIn = FRAX_ADDRESS;
        uint256 amountIn = TEN_THOUSAND_D18;
        uint256 minPHOOut = TEN_THOUSAND_D18 * 99 / 100;

        uint256 fraxVaultBalanceBefore = frax.balanceOf(address(fraxVault));
        uint256 user1FRAXBalanceBefore = frax.balanceOf(user1);
        uint256 user1PHOBalanceBefore = pho.balanceOf(user1);
        uint256 tellerDispatcherMintBalanceBefore = teller.mintingBalances(address(dispatcher));

        vm.expectEmit(true, true, false, true);
        emit Dispatched(user1, FRAX_ADDRESS, amountIn, TEN_THOUSAND_D18);
        vm.prank(user1);
        dispatcher.dispatchCollateral(FRAX_ADDRESS, amountIn, minPHOOut);

        uint256 fraxVaultBalanceAfter = frax.balanceOf(address(fraxVault));
        uint256 user1FRAXBalanceAfter = frax.balanceOf(user1);
        uint256 user1PHOBalanceAfter = pho.balanceOf(user1);
        uint256 tellerDispatcherMintBalanceAfter = teller.mintingBalances(address(dispatcher));

        assertEq(fraxVaultBalanceAfter, fraxVaultBalanceBefore + amountIn);
        assertEq(user1FRAXBalanceAfter, user1FRAXBalanceBefore - amountIn);
        assertEq(user1PHOBalanceAfter, user1PHOBalanceBefore + TEN_THOUSAND_D18);
        assertEq(
            tellerDispatcherMintBalanceAfter, tellerDispatcherMintBalanceBefore + TEN_THOUSAND_D18
        );
    }

    function testCannotDispatchCollateralZeroAddress() public {
        vm.expectRevert("Dispatcher: zero address detected");
        dispatcher.dispatchCollateral(address(0), TEN_THOUSAND_D18, TEN_THOUSAND_D18);
    }

    function testCannotDispatchCollateralZeroValue() public {
        vm.expectRevert("Dispatcher: zero value detected");
        dispatcher.dispatchCollateral(USDC_ADDRESS, 0, 0);
    }

    function testCannotDispatchCollateralTokenNotAccepted() public {
        vm.expectRevert("Dispatcher: token not accepted");
        dispatcher.dispatchCollateral(FRAXBP_LP_TOKEN, TEN_THOUSAND_D18, TEN_THOUSAND_D18);
    }

    function testCannotDispatchCollateralSlippageReached() public {
        priceOracle.setUSDCUSDPrice(980000);
        vm.expectRevert("Dispatcher: max slippage reached");

        vm.prank(user1);
        dispatcher.dispatchCollateral(USDC_ADDRESS, TEN_THOUSAND_D6, TEN_THOUSAND_D18);
    }

    /// redeemPHO()

    function testRedeemPHOForUSDC() public {
        // mint PHO for USDC for user1
        testDispatchCollateralUSDC();

        uint256 phoIn = TEN_THOUSAND_D18;
        uint256 minCollateralOut = TEN_THOUSAND_D6 * 99 / 100;

        vm.prank(user1);
        pho.approve(address(dispatcher), TEN_THOUSAND_D18);

        uint256 usdcVaultBalanceBefore = usdc.balanceOf(address(usdcVault));
        uint256 user1USDCBalanceBefore = usdc.balanceOf(user1);
        uint256 user1PHOBalanceBefore = pho.balanceOf(user1);

        vm.expectEmit(true, true, false, true);
        emit Redeemed(user1, USDC_ADDRESS, phoIn, TEN_THOUSAND_D6);
        vm.prank(user1);
        dispatcher.redeemPHO(USDC_ADDRESS, TEN_THOUSAND_D18, minCollateralOut);

        uint256 usdcVaultBalanceAfter = usdc.balanceOf(address(usdcVault));
        uint256 user1USDCBalanceAfter = usdc.balanceOf(user1);
        uint256 user1PHOBalanceAfter = pho.balanceOf(user1);

        assertEq(usdcVaultBalanceAfter, usdcVaultBalanceBefore - TEN_THOUSAND_D6);
        assertEq(user1USDCBalanceAfter, user1USDCBalanceBefore + TEN_THOUSAND_D6);
        assertEq(user1PHOBalanceAfter, user1PHOBalanceBefore - TEN_THOUSAND_D18);
    }

    function testRedeemPHOForFRAX() public {
        // mint PHO for USDC for user1
        testDispatchCollateralFRAX();

        uint256 phoIn = TEN_THOUSAND_D18;
        uint256 minCollateralOut = TEN_THOUSAND_D18 * 99 / 100;

        vm.prank(user1);
        pho.approve(address(dispatcher), TEN_THOUSAND_D18);

        uint256 fraxVaultBalanceBefore = frax.balanceOf(address(fraxVault));
        uint256 user1FRAXBalanceBefore = frax.balanceOf(user1);
        uint256 user1PHOBalanceBefore = pho.balanceOf(user1);

        vm.expectEmit(true, true, false, true);
        emit Redeemed(user1, FRAX_ADDRESS, phoIn, TEN_THOUSAND_D18);
        vm.prank(user1);
        dispatcher.redeemPHO(FRAX_ADDRESS, TEN_THOUSAND_D18, minCollateralOut);

        uint256 fraxVaultBalanceAfter = frax.balanceOf(address(fraxVault));
        uint256 user1FRAXBalanceAfter = frax.balanceOf(user1);
        uint256 user1PHOBalanceAfter = pho.balanceOf(user1);

        assertEq(fraxVaultBalanceAfter, fraxVaultBalanceBefore - TEN_THOUSAND_D18);
        assertEq(user1FRAXBalanceAfter, user1FRAXBalanceBefore + TEN_THOUSAND_D18);
        assertEq(user1PHOBalanceAfter, user1PHOBalanceBefore - TEN_THOUSAND_D18);
    }

    function testCannotRedeemPHOZeroAddress() public {
        vm.expectRevert("Dispatcher: zero address detected");
        dispatcher.redeemPHO(address(0), TEN_THOUSAND_D18, TEN_THOUSAND_D6);
    }

    function testCannotRedeemPHOZeroValue() public {
        vm.expectRevert("Dispatcher: zero value detected");
        dispatcher.redeemPHO(USDC_ADDRESS, 0, 0);
    }

    function testCannotRedeemPHOTokenNotAccepted() public {
        vm.expectRevert("Dispatcher: token not accepted");
        dispatcher.redeemPHO(FRAXBP_LP_TOKEN, TEN_THOUSAND_D18, TEN_THOUSAND_D18);
    }

    function testCannotRedeemPHOVaultTooLow() public {
        vm.expectRevert("Dispatcher: vault too low");
        vm.prank(user1);
        dispatcher.redeemPHO(USDC_ADDRESS, TEN_THOUSAND_D18, TEN_THOUSAND_D6);
    }

    function testCannotRedeemPHOSlippageReached() public {
        testDispatchCollateralUSDC();

        priceOracle.setUSDCUSDPrice(1020000);
        vm.expectRevert("Dispatcher: max slippage reached");

        vm.prank(user1);
        dispatcher.redeemPHO(USDC_ADDRESS, TEN_THOUSAND_D18, TEN_THOUSAND_D6);
    }

    /// addVault()

    function testAddVault() public {
        vm.prank(owner);
        dispatcher.removeVault(address(fraxVault));
        assertTrue(dispatcher.vaults(FRAX_ADDRESS) == address(0));

        vm.expectEmit(true, false, false, true);
        emit VaultAdded(address(fraxVault));
        vm.prank(owner);
        dispatcher.addVault(address(fraxVault));

        assertTrue(dispatcher.vaults(FRAX_ADDRESS) == address(fraxVault));
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
