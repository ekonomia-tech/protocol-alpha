// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseSetup.t.sol";
import "src/contracts/TON.sol";
import "src/contracts/ZeroCouponBond.sol";

contract ZeroCouponBondTest is BaseSetup {
    event BondIssued(address indexed depositor, uint256 depositAmount);
    event BondRedeemed(address indexed redeemer, uint256 redeemAmount);

    ZeroCouponBond public usdcZeroCouponBond;
    ZeroCouponBond public daiZeroCouponBond;
    ZeroCouponBond public phoZeroCouponBond;

    string public USDC_BOND_TOKEN_NAME = "USDC-1Year";
    string public USDC_BOND_TOKEN_SYMBOL = "USDC-1Y";
    string public DAI_BOND_TOKEN_NAME = "DAI-1Year";
    string public DAI_BOND_TOKEN_SYMBOL = "DAI-1Y";
    string public PHO_BOND_TOKEN_NAME = "PHO-1Year";
    string public PHO_BOND_TOKEN_SYMBOL = "PHO-1Y";
    uint256 public constant USDC_INTEREST_RATE = 5e5; // 5%
    uint256 public constant DAI_INTEREST_RATE = 4e5; // 4%
    uint256 public constant PHO_INTEREST_RATE = 3e5; // 3%
    uint256 public USDC_MATURITY;
    uint256 public DAI_MATURITY;
    uint256 public PHO_MATURITY;

    /// private functions
    function _whitelistCaller(address caller, uint256 ceiling) private {
        vm.prank(owner);
        teller.whitelistCaller(caller, ceiling);
    }

    function setUp() public {
        _whitelistCaller(owner, tenThousand_d18);
        _whitelistCaller(user1, oneHundred_d18);

        USDC_MATURITY = block.timestamp + 1000;
        DAI_MATURITY = block.timestamp + 1000;
        PHO_MATURITY = block.timestamp + 1000;

        usdcZeroCouponBond = new ZeroCouponBond(
            address(owner),
            address(pho),
            address(usdc),
            USDC_BOND_TOKEN_NAME,
            USDC_BOND_TOKEN_SYMBOL,
            USDC_INTEREST_RATE,
            USDC_MATURITY
        );

        daiZeroCouponBond = new ZeroCouponBond(
            address(owner),
            address(pho),
            address(dai),
            DAI_BOND_TOKEN_NAME,
            DAI_BOND_TOKEN_SYMBOL,
            DAI_INTEREST_RATE,
            DAI_MATURITY
        );

        phoZeroCouponBond = new ZeroCouponBond(
            address(owner),
            address(pho),
            address(pho),
            PHO_BOND_TOKEN_NAME,
            PHO_BOND_TOKEN_SYMBOL,
            PHO_INTEREST_RATE,
            PHO_MATURITY
        );

        assertEq(usdcZeroCouponBond.totalSupply(), 0);
        assertEq(daiZeroCouponBond.totalSupply(), 0);
        assertEq(phoZeroCouponBond.totalSupply(), 0);

        // Fund user with USDC
        vm.prank(richGuy);
        usdc.transfer(user1, tenThousand_d6);
        // Fund user with DAI
        vm.prank(daiWhale);
        dai.transfer(user1, tenThousand_d18);
        // Mint PHO to user
        vm.prank(owner);
        teller.mintPHO(address(user1), oneHundred_d18);

        // Approve sending USDC to USDC ZCB contract
        vm.prank(user1);
        usdc.approve(address(usdcZeroCouponBond), tenThousand_d6);
        // Approve sending DAI to DAI ZCB contract
        vm.prank(user1);
        dai.approve(address(daiZeroCouponBond), tenThousand_d18);
        // Approve sending PHO to PHO ZCB contract
        vm.prank(user1);
        pho.approve(address(phoZeroCouponBond), oneHundred_d18);

        // Mint PHO to USDC ZCB contract
        vm.prank(owner);
        teller.mintPHO(address(usdcZeroCouponBond), oneThousand_d18);
        // Mint PHO to DAI ZCB contract
        vm.prank(owner);
        teller.mintPHO(address(daiZeroCouponBond), oneThousand_d18);
        // Mint PHO to DAI ZCB contract
        vm.prank(owner);
        teller.mintPHO(address(phoZeroCouponBond), oneThousand_d18);
    }

    // Cannot set controller to address(0)
    function testCannotMakeZCBWithControllerZeroAddress() public {
        vm.expectRevert("ZeroCouponBond: zero address detected");
        vm.prank(user1);
        usdcZeroCouponBond = new ZeroCouponBond(
            address(0),
            address(pho),
            address(usdc),
            USDC_BOND_TOKEN_NAME,
            USDC_BOND_TOKEN_SYMBOL,
            USDC_INTEREST_RATE,
            USDC_MATURITY
        );
    }

    // Cannot set pho to address(0)
    function testCannotMakeZCBWithPHOZeroAddress() public {
        vm.expectRevert("ZeroCouponBond: zero address detected");
        vm.prank(user1);
        usdcZeroCouponBond = new ZeroCouponBond(
            address(owner),
            address(0),
            address(usdc),
            USDC_BOND_TOKEN_NAME,
            USDC_BOND_TOKEN_SYMBOL,
            USDC_INTEREST_RATE,
            USDC_MATURITY
        );
    }

    // Cannot set pho to address(0)
    function testCannotMakeZCBWithDepositTokenZeroAddress() public {
        vm.expectRevert("ZeroCouponBond: zero address detected");
        vm.prank(user1);
        usdcZeroCouponBond = new ZeroCouponBond(
            address(owner),
            address(pho),
            address(0),
            USDC_BOND_TOKEN_NAME,
            USDC_BOND_TOKEN_SYMBOL,
            USDC_INTEREST_RATE,
            USDC_MATURITY
        );
    }

    // Cannot set maturityTimestamp <= block.timestamp
    function testCannotMakeZCBWithMaturityTimestampLow() public {
        vm.expectRevert("ZeroCouponBond: maturityTimestamp must be in future");
        vm.prank(user1);
        usdcZeroCouponBond = new ZeroCouponBond(
            address(owner),
            address(pho),
            address(usdc),
            USDC_BOND_TOKEN_NAME,
            USDC_BOND_TOKEN_SYMBOL,
            USDC_INTEREST_RATE,
            block.timestamp
        );
    }

    // Cannot set interest rate if not owner
    function testCannotSetInterestRateOnlyOwner() public {
        vm.expectRevert("ZeroCouponBond: not owner or controller");
        vm.prank(user1);
        usdcZeroCouponBond.setInterestRate(3e5);
    }

    // Basic deposit for non-18 decimals
    function testDepositBondUSDC() public {
        uint256 depositAmount = oneHundred_d6;
        // deposit
        vm.prank(user1);
        usdcZeroCouponBond.depositBond(depositAmount);
        // check expected mint amount
        uint256 expectedMint = ((depositAmount * (1e6 + USDC_INTEREST_RATE)) / 1e6) * 10 ** 12;
        assertEq(usdcZeroCouponBond.totalSupply(), expectedMint);
        assertEq(usdcZeroCouponBond.issuedAmount(user1), expectedMint);
    }

    // Basic deposit for standard 18 decimals
    function testDepositBondDAI() public {
        uint256 depositAmount = oneHundred_d18;
        // deposit
        vm.prank(user1);
        daiZeroCouponBond.depositBond(depositAmount);
        // check expected mint amount
        uint256 expectedMint = ((depositAmount * (1e6 + DAI_INTEREST_RATE)) / 1e6);
        assertEq(daiZeroCouponBond.totalSupply(), expectedMint);
        assertEq(daiZeroCouponBond.issuedAmount(user1), expectedMint);
    }

    // Cannot redeem bond before maturtity
    function testCannotRedeemBondBeforeMaturity() public {
        uint256 depositAmount = oneHundred_d6;
        uint256 redeemAmount = ((depositAmount * (1e6 + USDC_INTEREST_RATE)) / 1e6) * 10 ** 12;
        vm.prank(user1);
        usdcZeroCouponBond.depositBond(depositAmount);
        vm.expectRevert("ZeroCouponBond: maturityTimestamp not reached");
        vm.prank(user1);
        usdcZeroCouponBond.redeemBond(redeemAmount);
    }

    // Cannot redeem more than issued
    function testCannotRedeemBondMoreThanIssued() public {
        uint256 depositAmount = oneHundred_d6;
        uint256 redeemAmount = ((depositAmount * (1e6 + USDC_INTEREST_RATE)) / 1e6) * 10 ** 12;
        vm.warp(USDC_MATURITY);
        vm.prank(user1);
        usdcZeroCouponBond.depositBond(depositAmount / 2);
        vm.expectRevert("ZeroCouponBond: cannot redeem > issued");
        vm.prank(user1);
        usdcZeroCouponBond.redeemBond(redeemAmount);
    }

    // Test basic redeem with non 18 decimals
    function testRedeemBondUSDC() public {
        uint256 depositAmount = oneHundred_d6;
        uint256 redeemAmount = ((depositAmount * (1e6 + USDC_INTEREST_RATE)) / 1e6) * 10 ** 12;
        vm.warp(USDC_MATURITY);

        uint256 phoBalanceUserBefore = pho.balanceOf(user1);
        uint256 phoZCBBalanceBefore = pho.balanceOf(address(usdcZeroCouponBond));

        vm.prank(user1);
        usdcZeroCouponBond.depositBond(depositAmount);
        vm.prank(user1);
        usdcZeroCouponBond.redeemBond(redeemAmount);

        uint256 phoBalanceUserAfter = pho.balanceOf(user1);
        uint256 phoZCBBalanceAfter = pho.balanceOf(address(usdcZeroCouponBond));

        assertEq(phoBalanceUserAfter, phoBalanceUserBefore + redeemAmount);
        assertEq(phoZCBBalanceAfter, phoZCBBalanceBefore - redeemAmount);

        assertEq(usdcZeroCouponBond.issuedAmount(user1), 0);
    }

    // Test basic redeem with standard 18 decimals
    function testRedeemBondDAI() public {
        uint256 depositAmount = oneHundred_d18;
        uint256 redeemAmount = ((depositAmount * (1e6 + DAI_INTEREST_RATE)) / 1e6);
        vm.warp(DAI_MATURITY);

        uint256 phoBalanceUserBefore = pho.balanceOf(user1);
        uint256 phoZCBBalanceBefore = pho.balanceOf(address(daiZeroCouponBond));

        vm.prank(user1);
        daiZeroCouponBond.depositBond(depositAmount);
        vm.prank(user1);
        daiZeroCouponBond.redeemBond(redeemAmount);

        uint256 phoBalanceUserAfter = pho.balanceOf(user1);
        uint256 phoZCBBalanceAfter = pho.balanceOf(address(daiZeroCouponBond));

        assertEq(phoBalanceUserAfter, phoBalanceUserBefore + redeemAmount);
        assertEq(phoZCBBalanceAfter, phoZCBBalanceBefore - redeemAmount);

        assertEq(daiZeroCouponBond.issuedAmount(user1), 0);
    }

    // Test basic redeem with with PHO
    function testRedeemBondPHO() public {
        uint256 depositAmount = oneHundred_d18;
        uint256 redeemAmount = ((depositAmount * (1e6 + PHO_INTEREST_RATE)) / 1e6);
        vm.warp(PHO_MATURITY);

        uint256 phoBalanceUserBefore = pho.balanceOf(user1);
        uint256 phoZCBBalanceBefore = pho.balanceOf(address(phoZeroCouponBond));

        vm.prank(user1);
        phoZeroCouponBond.depositBond(depositAmount);

        uint256 phoBalanceUserAfterDeposit = pho.balanceOf(user1);
        uint256 phoZCBBalanceAfterDeposit = pho.balanceOf(address(phoZeroCouponBond));

        assertEq(phoBalanceUserAfterDeposit, phoBalanceUserBefore - depositAmount);
        assertEq(phoZCBBalanceAfterDeposit, phoZCBBalanceBefore + depositAmount);

        vm.prank(user1);
        phoZeroCouponBond.redeemBond(redeemAmount);

        uint256 phoBalanceUserAfterRedeem = pho.balanceOf(user1);
        uint256 phoZCBBalanceAfterRedeem = pho.balanceOf(address(phoZeroCouponBond));

        assertEq(phoBalanceUserAfterRedeem, phoBalanceUserAfterDeposit + redeemAmount);
        assertEq(phoZCBBalanceAfterRedeem, phoZCBBalanceAfterDeposit - redeemAmount);

        assertEq(phoZeroCouponBond.issuedAmount(user1), 0);
    }
}
