// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {PHO} from "../src/contracts/PHO.sol";
import {PIDController} from "../src/contracts/PIDController.sol";
import {TON} from "../src/contracts/TON.sol";
import {DummyOracle} from "../src/oracle/DummyOracle.sol";
import {Pool} from "../src/contracts/Pool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/interfaces/curve/ICurve.sol";
import "src/interfaces/curve/ICurveFactory.sol";

abstract contract BaseSetup is Test {
    struct Balance {
        uint256 usdc;
        uint256 pho;
        uint256 ton;
    }

    PHO public pho;
    TON public ton;
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
    address public richGuy = 0x72A53cDBBcc1b9efa39c834A540550e23463AAcB;
    address public fraxBPLPToken = 0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC;
    address public fraxBPAddress = 0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2;
    address public metaPoolFactoryAddress = 0xB9fC157394Af804a3578134A6585C0dc9cc990d4;
    address public fraxRichGuy = 0xd3d176F7e4b43C70a68466949F6C64F06Ce75BB9;
    address public fraxAddress = 0x853d955aCEf822Db058eb8505911ED77F175b99e;
    address public fraxBPLUSD = 0x497CE58F34605B9944E6b15EcafE6b001206fd25;

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
    uint256 public constant one_m_d6 = 1000000 * 10 ** 6;
    uint256 public constant one_m_d18 = 1000000 * 10 ** 18;
    uint256 public constant two_m_d6 = 1000000 * 10 ** 6;
    uint256 public constant two_m_d18 = 1000000 * 10 ** 18;
    uint256 public constant five_m_d6 = 5000000 * 10 ** 6;
    uint256 public constant five_m_d18 = 5000000 * 10 ** 18;
    uint256 public constant six_m_d6 = 6000000 * 10 ** 6;
    uint256 public constant six_m_d18 = 6000000 * 10 ** 18;

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
        string memory RPC_URL = vm.envString("RPC_URL");
        if (bytes(RPC_URL).length == 0) {
            revert("Please provide RPC_URL in your .env file");
        }
        uint256 fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        vm.startPrank(owner);
        priceOracle = new DummyOracle();
        pho = new PHO("Pho", "PHO", owner, timelock_address);
        ton = new TON("TON", "TON", address(priceOracle), timelock_address);
        ton.setPHOAddress(address(pho));

        pid = new PIDController(address(pho), owner, timelock_address, address(priceOracle));
        pid.setMintingFee(9500); // .95% at genesis
        pid.setRedemptionFee(4500); // .45% at genesis
        pid.setController(controller);
        pho.setController(controller);

        usdc = IERC20(USDC_ADDRESS);
        pool_usdc =
        new Pool(address(pho), address(ton), address(pid), USDC_ADDRESS, owner, address(priceOracle), POOL_CEILING);
        pho.addPool(address(pool_usdc));

        // new code to accomodate not using constructor to mint unbacked PHO for tests
        usdc.approve(address(pool_usdc), GENESIS_SUPPLY_d6);
        pool_usdc.mint1t1PHO(GENESIS_SUPPLY_d6, GENESIS_SUPPLY_d18);

        pho.transfer(user1, tenThousand_d18);
        pho.transfer(user2, tenThousand_d18);
        pho.transfer(user3, tenThousand_d18);

        pool_usdc2 =
        new Pool(address(pho), address(ton), address(pid), USDC_ADDRESS, owner, address(priceOracle), POOL_CEILING);
        pho.addPool(address(pool_usdc2));

        usdc = IERC20(USDC_ADDRESS);

        vm.stopPrank();
    }

    /// Helpers

    function _getAccountBalance(address _account) internal returns (Balance memory) {
        uint256 usdcBalance = usdc.balanceOf(_account);
        uint256 phoBalance = pho.balanceOf(_account);
        uint256 tonBalance = ton.balanceOf(_account);

        return Balance(usdcBalance, phoBalance, tonBalance);
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

    function _getTON(address _to, uint256 _amount) internal {
        vm.prank(address(pool_usdc));
        ton.mint(_to, _amount);
    }

    function _approveTON(address _owner, address _spender, uint256 _amount) internal {
        vm.prank(_owner);
        ton.approve(_spender, _amount);
    }

    function _fundAndApproveTON(
        address _owner,
        address _spender,
        uint256 _amountIn,
        uint256 _amountOut
    )
        internal
    {
        _getTON(_owner, _amountIn);
        _approveTON(_owner, _spender, _amountOut);
    }

    function _deployFraxBPPHOPool() internal returns (address) {
        IERC20 frax = IERC20(fraxAddress);
        IERC20 fraxBPLP = IERC20(fraxBPLPToken);
        ICurve fraxBP = ICurve(fraxBPAddress);
        ICurveFactory curveFactory = ICurveFactory(metaPoolFactoryAddress);

        _fundAndApproveUSDC(owner, address(fraxBP), tenThousand_d6, tenThousand_d6);

        uint256[2] memory fraxBPmetaLiquidity;
        fraxBPmetaLiquidity[0] = tenThousand_d18; // frax
        fraxBPmetaLiquidity[1] = tenThousand_d6; // usdc
        uint256 minLPOut = tenThousand_d18;

        vm.startPrank(fraxRichGuy);
        frax.transfer(owner, tenThousand_d18 * 5);
        vm.stopPrank();

        vm.startPrank(owner);

        usdc.approve(address(fraxBP), tenThousand_d6);
        frax.approve(address(fraxBP), tenThousand_d18);

        fraxBP.add_liquidity(fraxBPmetaLiquidity, 0);

        address fraxBPPhoMetapoolAddress = curveFactory.deploy_metapool(
            address(fraxBP), "FRAXBP/PHO", "FRAXBPPHO", address(pho), 200, 4000000, 0
        );

        ICurve fraxBPPhoMetapool = ICurve(fraxBPPhoMetapoolAddress);
        pho.approve(address(fraxBPPhoMetapool), tenThousand_d18);
        fraxBPLP.approve(address(fraxBPPhoMetapool), tenThousand_d18);

        uint256[2] memory metaLiquidity;
        metaLiquidity[0] = tenThousand_d18;
        metaLiquidity[1] = tenThousand_d18;

        fraxBPPhoMetapool.add_liquidity(metaLiquidity, 0);
        
        return fraxBPPhoMetapoolAddress;
    }
}
