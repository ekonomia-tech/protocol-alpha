// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {EUSD} from "../src/contracts/EUSD.sol";
import {PIDController} from "../src/contracts/PIDController.sol";
import {Share} from "../src/contracts/Share.sol";
import {DummyOracle} from "../src/oracle/DummyOracle.sol";
import {Pool} from "../src/contracts/Pool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract BaseSetup is Test {
    struct Balance {
        uint256 usdc;
        uint256 eusd;
        uint256 share;
    }

    EUSD public eusd;
    Share public share;
    PIDController public pid;
    DummyOracle public priceOracle;
    Pool public pool_usdc;
    Pool public pool_usdc2;

    IERC20 usdc;

    address public owner = 0xed320Bf569E5F3c4e9313391708ddBFc58e296bb; // NOTE - vitalik.eth for tests but we may need a different address to supply USDC depending on our tests - vitalik only has 30k USDC
    address public timelock_address = address(100);
    address public controller = address(101);
    address public user1 = address(1);
    address public user2 = address(2);
    address public user3 = address(3);
    address public dummyAddress = address(4);
    address public richGuy = 0xed320Bf569E5F3c4e9313391708ddBFc58e296bb;

    uint256 public constant one_d18 = 10 ** 18;
    uint256 public constant one_d6 = 10 ** 6;
    uint256 public constant ten_d18 = 10 * 10 ** 18;
    uint256 public constant ten_d6 = 10 * 10 ** 6;
    uint256 public constant fifty_d18 = 50 * 10 ** 18;
    uint256 public constant fifty_d6 = 50 * 10 ** 6;
    uint256 public constant oneHundred_d18 = 100 * 10 ** 18;
    uint256 public constant oneHundred_d6 = 100 * 10 ** 6;
    uint256 public constant twoHundred_d18 = 200 * 10 ** 18;
    uint256 public constant twoHundred_d6 = 200 * 10 ** 6;
    uint256 public constant fiveHundred_d18 = 500 * 10 ** 18;
    uint256 public constant fiveHundred_d6 = 500 * 10 ** 6;
    uint256 public constant oneThousand_d18 = 1000 * 10 ** 18;
    uint256 public constant oneThousand_d6 = 1000 * 10 ** 6;
    uint256 public constant tenThousand_d18 = 10000 * 10 ** 18;
    uint256 public constant tenThousand_d6 = 10000 * 10 ** 6;

    uint256 public constant overPeg = (10 ** 6) + 6000;
    uint256 public constant underPeg = (10 ** 6) - (6000);

    uint256 public constant GENESIS_SUPPLY_d18 = 100000 * 10 ** 18;
    uint256 public constant GENESIS_SUPPLY_d6 = 100000 * 10 ** 6;

    uint256 public constant PRICE_PRECISION = 10 ** 6;
    uint256 public constant missing_decimals = 10 ** 12;

    address public constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint256 public constant POOL_CEILING = (2 ** 256) - 1;

    constructor() {
        vm.startPrank(owner);
        priceOracle = new DummyOracle();
        eusd = new EUSD("Eusd", "EUSD", owner, timelock_address);
        share = new Share("Share", "SHARE", address(priceOracle), timelock_address);
        share.setEUSDAddress(address(eusd));

        pid = new PIDController(address(eusd), owner, timelock_address, address(priceOracle));
        pid.setMintingFee(9500); // .95% at genesis
        pid.setRedemptionFee(4500); // .45% at genesis
        pid.setController(controller);
        eusd.setController(controller);

        usdc = IERC20(USDC_ADDRESS);
        pool_usdc =
        new Pool(address(eusd), address(share), address(pid), USDC_ADDRESS, owner, address(priceOracle), POOL_CEILING);
        eusd.addPool(address(pool_usdc));

        // new code to accomodate not using constructor to mint unbacked EUSD for tests
        usdc.approve(address(pool_usdc), GENESIS_SUPPLY_d6);
        pool_usdc.mint1t1EUSD(GENESIS_SUPPLY_d6, GENESIS_SUPPLY_d18);

        eusd.transfer(user1, tenThousand_d18);
        eusd.transfer(user2, tenThousand_d18);
        eusd.transfer(user3, tenThousand_d18);

        pool_usdc2 =
        new Pool(address(eusd), address(share), address(pid), USDC_ADDRESS, owner, address(priceOracle), POOL_CEILING);
        eusd.addPool(address(pool_usdc2));

        usdc = IERC20(USDC_ADDRESS);

        vm.stopPrank();
    }

    /// Helpers

    function _getAccountBalance(address _account) internal returns (Balance memory) {
        uint256 usdcBalance = usdc.balanceOf(_account);
        uint256 eusdBalance = eusd.balanceOf(_account);
        uint256 shareBalance = share.balanceOf(_account);

        return Balance(usdcBalance, eusdBalance, shareBalance);
    }

    function _getUSDC(address to, uint256 _amount) internal {
        vm.prank(richGuy);
        usdc.transfer(to, _amount);
    }

    function _approveUSDC(address _owner, address _spender, uint256 _amount) internal {
        vm.prank(_owner);
        usdc.approve(_spender, _amount);
    }

    function _fundAndApproveUSDC(
        address _owner,
        address _spender,
        uint256 _amountIn,
        uint256 _amountOut
    )
        internal
    {
        _getUSDC(_owner, _amountIn);
        _approveUSDC(_owner, _spender, _amountOut);
    }

    function _getShare(address _to, uint256 _amount) internal {
        vm.prank(address(pool_usdc));
        share.mint(_to, _amount);
    }

    function _approveShare(address _owner, address _spender, uint256 _amount) internal {
        vm.prank(_owner);
        share.approve(_spender, _amount);
    }

    function _fundAndApproveShare(
        address _owner,
        address _spender,
        uint256 _amountIn,
        uint256 _amountOut
    )
        internal
    {
        _getShare(_owner, _amountIn);
        _approveShare(_owner, _spender, _amountOut);
    }
}
