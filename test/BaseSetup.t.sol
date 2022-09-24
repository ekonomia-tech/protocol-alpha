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

    address public owner = 0x72A53cDBBcc1b9efa39c834A540550e23463AAcB;
    // address public owner = 0xed320Bf569E5F3c4e9313391708ddBFc58e296bb; // NOTE - vitalik.eth for tests but we may need a different address to supply USDC depending on our tests - vitalik only has 30k USDC
    address public timelock_address = address(100);
    address public controller = address(101);
    address public user1 = address(1);
    address public user2 = address(2);
    address public user3 = address(3);
    address public dummyAddress = address(4);
    address public richGuy = 0x72A53cDBBcc1b9efa39c834A540550e23463AAcB;
 
    address public metaPoolFactoryAddress = 0xB9fC157394Af804a3578134A6585C0dc9cc990d4;
    address public fraxRichGuy = 0xd3d176F7e4b43C70a68466949F6C64F06Ce75BB9;

    address public constant ethNullAddress = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant PriceFeed_ETHUSD = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address public constant PriceFeed_USDCUSD = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address public constant PriceFeed_FRAXUSD = 0xB9E1E3A9feFf48998E45Fa90847ed4D467E8BcfD;

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
    uint256 public constant five_m_d6 = 5000000 * 10 ** 6;
    uint256 public constant five_m_d18 = 5000000 * 10 ** 18;
    uint256 public constant six_m_d6 = 6000000 * 10 ** 6;
    uint256 public constant six_m_d18 = 6000000 * 10 ** 18;

    uint256 public constant overPeg = (10 ** 6) + 6000;
    uint256 public constant underPeg = (10 ** 6) - (6000);

    uint256 public constant GENESIS_SUPPLY_d18 = 100000000 * 10 ** 18;
    uint256 public constant GENESIS_SUPPLY_d6 = 100000 * 10 ** 6;
    uint256 public constant PRICE_THRESHOLD = 100; // 10000 = 100%
    uint256 public period = 604800; // 1 week in seconds

    uint256 public constant PRICE_PRECISION = 10 ** 6;
    uint256 public constant missing_decimals = 10 ** 12;

    uint256 public constant precisionDifference = 10;

    address public constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public fraxAddress = 0x853d955aCEf822Db058eb8505911ED77F175b99e;
    address public fraxBPAddress = 0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2;
    address public fraxBPLPToken = 0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC;
    address public fraxBPLUSD = 0x497CE58F34605B9944E6b15EcafE6b001206fd25;
    // address public fraxChainlinkPriceFeed = 0xb9e1e3a9feff48998e45fa90847ed4d467e8bcfd;
    // address public usdcChainlinkPriceFeed = 0x8fffffd4afb6115b954bd326cbe7b4ba576818f6;
    // address public ethNullAddress = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    // address public ethUSDChainlinkPriceFeed = 0x5f4ec3df9cbd43714fe2740f5e3616155c5b8419;

    uint256 public constant POOL_CEILING = (2 ** 256) - 1;

    uint256 tellerCeiling = 2 * 100 * tenThousand_d18; // set to 2 million

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
        // priceFeed = new PriceFeed(); // TODO - setup in accordance to Niv's code or replace with his constructor if any.
        
        // // set base pricefeeds needed for CurveTWAPOracle
        // priceFeed.addFeed(fraxAddress, fraxChainlinkPriceFeed);
        // priceFeed.addFeed(USDC_ADDRESS, usdcChainlinkPriceFeed);
        // priceFeed.addFeed(ethNullAddress, ethUSDChainlinkPriceFeed);
        // // Chainlink priceFeed for Frax-USD: https://data.chain.link/ethereum/mainnet/stablecoins/frax-usd
        // // Chainlink priceFeed for USDC-USD: https://data.chain.link/ethereum/mainnet/stablecoins/usdc-usd

        teller = new Teller(address(pho), tellerCeiling);
        pho.setTeller(address(teller));

        dispatcher = new Dispatcher(address(pho), address(teller));
        teller.whitelistCaller(address(dispatcher), 2000 * tenThousand_d18);

        usdcVault = new Vault(address(pho), USDC_ADDRESS, address(priceOracle));
        fraxVault = new Vault(address(pho), fraxAddress, address(priceOracle));

        dispatcher.addVault(address(usdcVault));
        dispatcher.addVault(address(fraxVault));

        usdcVault.whitelistCaller(address(dispatcher));
        fraxVault.whitelistCaller(address(dispatcher));

        usdc = IERC20(USDC_ADDRESS);
        frax = IERC20(fraxAddress);

        priceFeed = new ChainlinkPriceFeed(precisionDifference);
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

    /// @notice funds owner with USDC, approves fraxBP to pull owner USDC, funds owner with FRAX from fraxRichGuy, approves fraxBP to pull owner FRAX, owner adds liquidity to fraxBP, owner deploys metapool FraxBP/PHO, owner adds liquidity to FraxBP/PHO. Owner has all the LP tokens to start for FraxBP/PHO
    function _deployFraxBPPHOPool() internal returns (address) {
        vm.prank(address(teller));
        pho.mint(owner, tenThousand_d18);

        IERC20 frax = IERC20(fraxAddress);
        IERC20 fraxBPLP = IERC20(fraxBPLPToken);
        ICurvePool fraxBP = ICurvePool(fraxBPAddress);
        ICurveFactory curveFactory = ICurveFactory(metaPoolFactoryAddress);

        _fundAndApproveUSDC(owner, address(fraxBP), tenThousand_d6, tenThousand_d6);

        uint256[2] memory fraxBPmetaLiquidity;
        fraxBPmetaLiquidity[0] = tenThousand_d18; // frax
        fraxBPmetaLiquidity[1] = tenThousand_d6; // usdc
        uint256 minLPOut = tenThousand_d18;

        vm.prank(fraxRichGuy);
        frax.transfer(owner, tenThousand_d18 * 5);

        vm.startPrank(owner);

        usdc.approve(address(fraxBP), tenThousand_d6);
        frax.approve(address(fraxBP), tenThousand_d18);

        fraxBP.add_liquidity(fraxBPmetaLiquidity, 0);

        address fraxBPPhoMetapoolAddress = curveFactory.deploy_metapool(
            address(fraxBP), "FRAXBP/PHO", "FRAXBPPHO", address(pho), 200, 4000000, 0
        );

        ICurvePool fraxBPPhoMetapool = ICurvePool(fraxBPPhoMetapoolAddress);
        pho.approve(address(fraxBPPhoMetapool), tenThousand_d18);
        fraxBPLP.approve(address(fraxBPPhoMetapool), tenThousand_d18);

        uint256[2] memory metaLiquidity;
        metaLiquidity[0] = tenThousand_d18;
        metaLiquidity[1] = tenThousand_d18;

        fraxBPPhoMetapool.add_liquidity(metaLiquidity, 0);

        vm.stopPrank();

        return fraxBPPhoMetapoolAddress;
    }

    /// @notice funds owner with USDC, approves fraxBP to pull owner USDC, funds owner with FRAX from fraxRichGuy, approves fraxBP to pull owner FRAX, owner adds liquidity to fraxBP, owner deploys metapool FraxBP/PHO, owner adds liquidity to FraxBP/PHO. Owner has all the LP tokens to start for FraxBP/PHO
    function _deployFraxBPPHOPoolOneMillion() internal returns (address) {
        IERC20 frax = IERC20(fraxAddress);
        IERC20 fraxBPLP = IERC20(fraxBPLPToken);
        ICurvePool fraxBP = ICurvePool(fraxBPAddress);
        ICurveFactory curveFactory = ICurveFactory(metaPoolFactoryAddress);

        _fundAndApproveUSDC(owner, address(fraxBP), one_m_d6, one_m_d6);

        uint256[2] memory fraxBPmetaLiquidity;
        fraxBPmetaLiquidity[0] = one_m_d18; // frax
        fraxBPmetaLiquidity[1] = one_m_d6; // usdc
        uint256 minLPOut = one_m_d18;

        vm.startPrank(fraxRichGuy);
        frax.transfer(owner, one_m_d18 * 5);
        vm.stopPrank();

        vm.startPrank(owner);

        usdc.approve(address(fraxBP), one_m_d6);
        frax.approve(address(fraxBP), one_m_d18);

        fraxBP.add_liquidity(fraxBPmetaLiquidity, 0);

        address fraxBPPhoMetapoolAddress = curveFactory.deploy_metapool(
            address(fraxBP), "FRAXBP/PHO", "FRAXBPPHO", address(pho), 200, 4000000, 0
        );

        ICurvePool fraxBPPhoMetapool = ICurvePool(fraxBPPhoMetapoolAddress);
        pho.approve(address(fraxBPPhoMetapool), one_m_d18);
        fraxBPLP.approve(address(fraxBPPhoMetapool), one_m_d18);

        uint256[2] memory metaLiquidity;
        metaLiquidity[0] = one_m_d18;
        metaLiquidity[1] = one_m_d18;

        fraxBPPhoMetapool.add_liquidity(metaLiquidity, 0);

        return fraxBPPhoMetapoolAddress;
    }
}
