// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {PHO} from "../src/contracts/PHO.sol";
import {TON} from "../src/contracts/TON.sol";
import {DummyOracle} from "../src/oracle/DummyOracle.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/interfaces/curve/ICurvePool.sol";
import "src/interfaces/curve/ICurveFactory.sol";
import "src/contracts/Teller.sol";
import "src/contracts/Dispatcher.sol";
import "src/contracts/Vault.sol";
import "src/oracle/ChainlinkPriceFeed.sol";
import "src/oracle/PHOTWAPOracle.sol";
import "src/interfaces/IPHOOracle.sol";

abstract contract BaseSetup is Test {
    struct Balance {
        uint256 usdc;
        uint256 pho;
        uint256 ton;
    }

    PHO public pho;
    TON public ton;
    Teller public teller;
    DummyOracle public priceOracle;
    ChainlinkPriceFeed public priceFeed;
    Dispatcher dispatcher;
    Vault usdcVault;
    Vault fraxVault;
    IERC20 usdc;
    IERC20 frax;
    IERC20 fraxBPLP;
    ICurvePool fraxBP;
    ICurveFactory curveFactory;
    ICurvePool fraxBPPhoMetapool;

    address public owner = 0xed320Bf569E5F3c4e9313391708ddBFc58e296bb;
    address public timelock_address = address(100);
    address public controller = address(101);
    address public user1 = address(1);
    address public user2 = address(2);
    address public user3 = address(3);
    address public dummyAddress = address(4);
    address public richGuy = 0x72A53cDBBcc1b9efa39c834A540550e23463AAcB;
    address public metaPoolFactoryAddress = 0xB9fC157394Af804a3578134A6585C0dc9cc990d4;
    address public fraxRichGuy = 0xd3d176F7e4b43C70a68466949F6C64F06Ce75BB9;

    address public constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant FRAX_ADDRESS = 0x853d955aCEf822Db058eb8505911ED77F175b99e;
    address public constant FRAXBP_ADDRESS = 0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2;
    address public constant FRAXBP_LP_TOKEN = 0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC;
    address public constant FRAXBP_POOL = 0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2;
    address public constant FRAXBP_LUSD = 0x497CE58F34605B9944E6b15EcafE6b001206fd25;

    address public constant ETH_NULL_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant PRICEFEED_ETHUSD = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address public constant PRICEFEED_USDCUSD = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address public constant PRICEFEED_FRAXUSD = 0xB9E1E3A9feFf48998E45Fa90847ed4D467E8BcfD;

    uint256 public constant ONE_D6 = 10 ** 6;
    uint256 public constant ONE_HUNDRED_D18 = 100 * 10 ** 18;
    uint256 public constant ONE_THOUSAND_D18 = 1000 * 10 ** 18;
    uint256 public constant ONE_THOUSAND_D6 = 1000 * 10 ** 6;
    uint256 public constant TEN_THOUSAND_D18 = 10000 * 10 ** 18;
    uint256 public constant TEN_THOUSAND_D6 = 10000 * 10 ** 6;

    uint256 public constant ONE_HUNDRED_THOUSAND_D18 = 100000 * 10 ** 18;
    uint256 public constant ONE_MILLION_D6 = 1000000 * 10 ** 6;
    uint256 public constant ONE_MILLION_D18 = 1000000 * 10 ** 18;

    uint256 public constant OVERPEG = (10 ** 6) + 6000;
    uint256 public constant UNDERPEG = (10 ** 6) - (6000);

    uint256 public constant GENESIS_SUPPLY_D18 = 100000000 * 10 ** 18;

    uint256 public constant PRICE_PRECISION = 10 ** 6;
    uint256 public constant DECIMALS_DIFFERENCE = 10 ** 12;
    uint256 public constant PHO_PRICE_PRECISION = 10 ** 18;
    uint256 public constant FEED_PRECISION = 10 ** 10;

    // phoOracle specific
    uint256 public constant PRICE_THRESHOLD = 100000; // 10%, since 10 ** 6 (1000000) = 100%
    uint256 public constant PRECISION_DIFFERENCE = 10;
    uint256 public period = 1 weeks;

    uint256 public constant POOL_CEILING = (2 ** 256) - 1;

    uint256 tellerCeiling = 2 * 100 * TEN_THOUSAND_D18; // set to 2 million

    constructor() {
        string memory RPC_URL = vm.envString("RPC_URL");
        if (bytes(RPC_URL).length == 0) {
            revert("Please provide RPC_URL in your .env file");
        }
        uint256 fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        vm.startPrank(owner);
        priceOracle = new DummyOracle();
        pho = new PHO("PHO", "PHO");
        ton = new TON("TON", "TON");

        teller = new Teller(address(pho), tellerCeiling);
        pho.setTeller(address(teller));

        dispatcher = new Dispatcher(address(pho), address(teller));
        teller.whitelistCaller(address(dispatcher), 2000 * TEN_THOUSAND_D18);

        usdcVault = new Vault(address(pho), USDC_ADDRESS, address(priceOracle));
        fraxVault = new Vault(address(pho), FRAX_ADDRESS, address(priceOracle));

        dispatcher.addVault(address(usdcVault));
        dispatcher.addVault(address(fraxVault));

        usdcVault.whitelistCaller(address(dispatcher));
        fraxVault.whitelistCaller(address(dispatcher));

        usdc = IERC20(USDC_ADDRESS);
        frax = IERC20(FRAX_ADDRESS);

        priceFeed = new ChainlinkPriceFeed(PRECISION_DIFFERENCE);

        curveFactory = ICurveFactory(metaPoolFactoryAddress);
        fraxBP = ICurvePool(FRAXBP_ADDRESS);
        vm.stopPrank();
    }

    /// Helpers

    function _getAccountBalance(address _account) internal view returns (Balance memory) {
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
    ) internal {
        _getUSDC(_owner, _amountIn);
        _approveUSDC(_owner, _spender, _amountOut);
    }

    function _getTON(address _to, uint256 _amount) internal {
        vm.prank(owner);
        ton.transfer(_to, _amount);
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
    ) internal {
        _getTON(_owner, _amountIn);
        _approveTON(_owner, _spender, _amountOut);
    }

    function _getFRAX(address _to, uint256 _amount) internal {
        vm.prank(fraxRichGuy);
        frax.transfer(_to, _amount);
    }

    function _approveFRAX(address _owner, address _spender, uint256 _amount) internal {
        vm.prank(_owner);
        frax.approve(_spender, _amount);
    }

    function _fundAndApproveFRAX(
        address _owner,
        address _spender,
        uint256 _amountIn,
        uint256 _amountOut
    ) internal {
        _getFRAX(_owner, _amountIn);
        _approveFRAX(_owner, _spender, _amountOut);
    }

    function _deployFraxBPPHOPool() internal returns (address) {
        vm.prank(address(teller));
        pho.mint(owner, TEN_THOUSAND_D18);

        frax = IERC20(FRAX_ADDRESS);
        fraxBPLP = IERC20(FRAXBP_LP_TOKEN);

        _fundAndApproveUSDC(owner, address(fraxBP), TEN_THOUSAND_D6, TEN_THOUSAND_D6);

        uint256[2] memory fraxBPmetaLiquidity;
        fraxBPmetaLiquidity[0] = TEN_THOUSAND_D18; // frax
        fraxBPmetaLiquidity[1] = TEN_THOUSAND_D6; // usdc

        vm.prank(fraxRichGuy);
        frax.transfer(owner, TEN_THOUSAND_D18 * 5);

        vm.startPrank(owner);

        usdc.approve(address(fraxBP), TEN_THOUSAND_D6);
        frax.approve(address(fraxBP), TEN_THOUSAND_D18);

        fraxBP.add_liquidity(fraxBPmetaLiquidity, 0);

        address fraxBPPhoMetapoolAddress = curveFactory.deploy_metapool(
            address(fraxBP), "FRAXBP/PHO", "FRAXBPPHO", address(pho), 200, 4000000, 0
        );

        fraxBPPhoMetapool = ICurvePool(fraxBPPhoMetapoolAddress);
        pho.approve(address(fraxBPPhoMetapool), TEN_THOUSAND_D18);
        fraxBPLP.approve(address(fraxBPPhoMetapool), TEN_THOUSAND_D18);

        uint256[2] memory metaLiquidity;
        metaLiquidity[0] = TEN_THOUSAND_D18;
        metaLiquidity[1] = TEN_THOUSAND_D18;

        fraxBPPhoMetapool.add_liquidity(metaLiquidity, 0);

        vm.stopPrank();

        return fraxBPPhoMetapoolAddress;
    }
}
