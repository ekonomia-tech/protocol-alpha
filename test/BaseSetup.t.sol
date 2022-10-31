// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@protocol/contracts/PHO.sol";
import "@protocol/contracts/TON.sol";
import "@protocol/contracts/Kernel.sol";
import "@protocol/contracts/ModuleManager.sol";
import "@oracle/ChainlinkPriceFeed.sol";
import "@oracle/PHOTWAPOracle.sol";
import "@oracle/IPHOOracle.sol";
import "@oracle/DummyOracle.sol";
import "@external/curve/ICurvePool.sol";
import "@external/curve/ICurveFactory.sol";
import "@governance/PHOGovernorBravoDelegate.sol";
import "@governance/PHOGovernorBravoDelegator.sol";
import {TONGovernorBravoDelegate} from "@governance/TONGovernorBravoDelegate.sol";
import {TONGovernorBravoDelegator} from "@governance/TONGovernorBravoDelegator.sol";

abstract contract BaseSetup is Test {
    /// errors

    error UnrecognizedProxy();

    struct Balance {
        uint256 usdc;
        uint256 pho;
        uint256 ton;
    }

    PHO public pho;
    TON public ton;
    ModuleManager public moduleManager;
    Kernel public kernel;
    DummyOracle public priceOracle;
    ChainlinkPriceFeed public priceFeed;
    IERC20 dai;
    IUSDC usdc;
    IERC20 frax;
    IERC20 fraxBPLP;
    ICurvePool fraxBP;
    ICurveFactory curveFactory;
    ICurvePool fraxBPPhoMetapool;

    PHOGovernorBravoDelegate public phoGovernanceDelegate;
    PHOGovernorBravoDelegator public phoGovernanceDelegator;
    TONGovernorBravoDelegate public tonGovernanceDelegate;
    TONGovernorBravoDelegator public tonGovernanceDelegator;
    address public TONGovernance;
    address public PHOGovernance;

    address public owner = 0xed320Bf569E5F3c4e9313391708ddBFc58e296bb;
    address public PHO_timelock_address = address(100);
    address public TON_timelock_address = address(103);
    address public controller = address(101);
    address public user1 = address(1);
    address public user2 = address(2);
    address public user3 = address(3);
    address public dummyAddress = address(4);
    address public module1 = address(5);
    address public richGuy = 0x72A53cDBBcc1b9efa39c834A540550e23463AAcB;
    address public daiWhale = 0xc08a8a9f809107c5A7Be6d90e315e4012c99F39a;
    address public fraxBPLPToken = 0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC;
    address public fraxBPAddress = 0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2;
    address public metaPoolFactoryAddress = 0xB9fC157394Af804a3578134A6585C0dc9cc990d4;
    address public fraxRichGuy = 0xd3d176F7e4b43C70a68466949F6C64F06Ce75BB9;

    address public constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant FRAX_ADDRESS = 0x853d955aCEf822Db058eb8505911ED77F175b99e;
    address public constant FRAXBP_ADDRESS = 0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2;
    address public constant FRAXBP_LP_TOKEN = 0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC;
    address public constant FRAXBP_POOL = 0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2;
    address public constant FRAXBP_LUSD = 0x497CE58F34605B9944E6b15EcafE6b001206fd25;
    address public constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant DAI_ADDRESS = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    address public constant ETH_NULL_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant PRICEFEED_ETHUSD = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address public constant PRICEFEED_USDCUSD = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address public constant PRICEFEED_FRAXUSD = 0xB9E1E3A9feFf48998E45Fa90847ed4D467E8BcfD;

    uint256 public constant USDC_DECIMALS = 6;
    uint256 public constant DAI_DECIMALS = 18;
    uint256 public constant PHO_DECIMALS = 18;

    uint256 public constant ONE_D6 = 10 ** 6;
    uint256 public constant ONE_HUNDRED_D6 = 100 * 10 ** 6;
    uint256 public constant ONE_HUNDRED_D18 = 100 * 10 ** 18;
    uint256 public constant ONE_THOUSAND_D18 = 1000 * 10 ** 18;
    uint256 public constant ONE_THOUSAND_D6 = 1000 * 10 ** 6;
    uint256 public constant TEN_THOUSAND_D18 = 10000 * 10 ** 18;
    uint256 public constant TEN_THOUSAND_D6 = 10000 * 10 ** 6;

    uint256 public constant ONE_HUNDRED_THOUSAND_D18 = 100000 * 10 ** 18;
    uint256 public constant ONE_HUNDRED_THOUSAND_D6 = 100000 * 10 ** 6;
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

    uint256 public constant VOTING_DELAY = 14400;
    uint256 public constant VOTING_PERIOD = 21600;

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

        // set up PHO Governance
        phoGovernanceDelegate = new PHOGovernorBravoDelegate();

        phoGovernanceDelegator = new PHOGovernorBravoDelegator(
            PHO_timelock_address,
            address(pho),
            owner,
            address(phoGovernanceDelegate),
            VOTING_PERIOD,
            VOTING_DELAY,
            ONE_HUNDRED_D18
        ); //PHOGovernorBravoDelegate is initialized here too through Delegator constructor

        PHOGovernance = address(phoGovernanceDelegator);

        (bool initiateSuccess, bytes memory initiateResult) = address(phoGovernanceDelegator).call(
            abi.encodeWithSignature("_initiate(address)", PHOGovernance)
        ); // NOTE - param passed - PHOGovernance is not needed w/ modifications made. See comment in PHOGovernorBravoDelegate.sol

        console.log("THIS IS initiateSuccess: ", initiateSuccess);

        (bool newInitialProposalIdSuccess, bytes memory newInitialProposalIdResult) =
            address(phoGovernanceDelegator).call(abi.encodeWithSignature("initialProposalId()"));

        uint256 newInitialProposalId = abi.decode(newInitialProposalIdResult, (uint256));
        console.log("UPDATED newInitialProposalId: ", newInitialProposalId);

        // setup TON Governance

        tonGovernanceDelegate = new TONGovernorBravoDelegate();

        tonGovernanceDelegator = new TONGovernorBravoDelegator(
            TON_timelock_address,
            address(ton),
            owner,
            address(tonGovernanceDelegate),
            VOTING_PERIOD,
            VOTING_DELAY,
            ONE_THOUSAND_D18
        ); //TONGovernorBravoDelegate is initialized here too through Delegator constructor

        TONGovernance = address(tonGovernanceDelegator);

        (bool TONInitiateSuccess, bytes memory TONinitiateResult) = address(tonGovernanceDelegator)
            .call(abi.encodeWithSignature("_initiate(address)", TONGovernance)); // NOTE - param passed - TONGovernance is not needed w/ modifications made. See comment in TONGovernorBravoDelegate.sol

        console.log("THIS IS TONinitiateSuccess: ", TONInitiateSuccess);

        // setup kernel

        kernel = new Kernel(address(pho), TONGovernance);

        moduleManager = new ModuleManager(
            address(kernel),
            PHOGovernance,
            TONGovernance
        );

        vm.stopPrank();

        vm.prank(TONGovernance);
        kernel.updateModuleManager(address(moduleManager));

        vm.startPrank(owner);

        pho.setKernel(address(kernel));
        ton.setKernel(address(kernel));

        dai = IERC20(DAI_ADDRESS);
        usdc = IUSDC(USDC_ADDRESS);
        dai = IERC20(DAI_ADDRESS);
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
        vm.prank(usdc.masterMinter());
        usdc.configureMinter(address(this), type(uint256).max);

        usdc.mint(to, _amount);
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

    function _getDAI(address to, uint256 _amount) internal {
        vm.prank(daiWhale);
        dai.transfer(to, _amount);
    }

    function _approveDAI(address _owner, address _spender, uint256 _amount) internal {
        vm.prank(_owner);
        dai.approve(_spender, _amount);
    }

    function _fundAndApproveDAI(
        address _owner,
        address _spender,
        uint256 _amountIn,
        uint256 _amountOut
    ) internal {
        _getDAI(_owner, _amountIn);
        _approveDAI(_owner, _spender, _amountOut);
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
        vm.prank(address(kernel));
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

    // governance helpers

    /// @notice Point of this is to provide owner (or other users) with enough PHO to actually push proposals forward and vote them through to be executed.
    /// TODO - start the genesis module using: genesisMint PHO && TON to the owner in PHO.sol && TON.sol (needed to be able to vote), owner proposes addModule(genesisModule), vm.roll(startBlock + 1), owner votes on that proposal so it passes quorumVotes minimum, vm.roll(endBlock + 1), owner `queue()` `addModule(genesisModule)` proposal, vm.warp(proposal.eta + 1), owner `execute()` `addModule(genesisModule)` proposal.

    function _initGovernorSetup() public {}

    function _propose(
        address _proxy,
        address[] memory _targets,
        uint256[] memory _values,
        string[] memory _signatures,
        bytes[] memory _callDatas,
        string memory _description
    ) internal returns (bytes memory) {
        address proxy;
        if (_proxy == PHOGovernance) {
            proxy = PHOGovernance;
        } else if (_proxy == TONGovernance) {
            proxy = TONGovernance;
        } else {
            revert UnrecognizedProxy();
        }

        (bool proposeSuccess, bytes memory proposeResult) = address(proxy).call(
            abi.encodeWithSignature(
                "propose(address[],uint256[],string[],bytes[],string)",
                _targets,
                _values,
                _signatures,
                _callDatas,
                _description
            )
        );

        return proposeResult;
    }

    function _castVote(address _proxy, uint256 _proposalId, uint8 _support) internal {
        address proxy;

        if (_proxy == PHOGovernance) {
            proxy = PHOGovernance;
        } else if (_proxy == TONGovernance) {
            proxy = TONGovernance;
        } else {
            revert UnrecognizedProxy();
        }

        (bool voteSuccess,) =
            proxy.call(abi.encodeWithSignature("castVote(uint,uint8)", _proposalId, _support));
    }

    function _queue(address _proxy, uint256 _proposalId) internal {
        address proxy;

        if (_proxy == PHOGovernance) {
            proxy = PHOGovernance;
        } else if (_proxy == TONGovernance) {
            proxy = TONGovernance;
        } else {
            revert UnrecognizedProxy();
        }

        (bool queueSuccess,) = proxy.call(abi.encodeWithSignature("queue(uint)", _proposalId));
    }

    function _execute(address _proxy, uint256 _proposalId) internal {
        address proxy;

        if (_proxy == PHOGovernance) {
            proxy = PHOGovernance;
        } else if (_proxy == TONGovernance) {
            proxy = TONGovernance;
        } else {
            revert UnrecognizedProxy();
        }

        (bool executeSuccess,) = proxy.call(abi.encodeWithSignature("execute(uint)", _proposalId));
    }

    function _cancel(address _proxy, uint256 _proposalId) internal {
        address proxy;

        if (_proxy == PHOGovernance) {
            proxy = PHOGovernance;
        } else if (_proxy == TONGovernance) {
            proxy = TONGovernance;
        } else {
            revert UnrecognizedProxy();
        }

        (bool cancelSuccess,) = proxy.call(abi.encodeWithSignature("cancel(uint)", _proposalId));
    }

    function _setUpAddedModule() internal {
        vm.startPrank(owner);

        address[] memory targets = new address[](1);
        targets[0] = address(moduleManager);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        string[] memory signatures = new string[](1);
        signatures[0] = "addModule(address _newModule)";
        bytes[] memory callDatas = new bytes[](1);
        callDatas[0] = abi.encode("address _newModule", module1);
        string memory description = "Add new module";

        bytes memory proposeSuccess =
            _propose(PHOGovernance, targets, values, signatures, callDatas, description);

        uint256 proposalStartBlock = block.number;

        vm.roll(block.number + VOTING_DELAY + 1);

        // check that proposal is set up well and get the proposalID.
        (bool newInitialProposalIdSuccess2, bytes memory newInitialProposalIdResult2) =
            PHOGovernance.call(abi.encodeWithSignature("initialProposalId()"));

        uint256 newInitialProposalId2 = abi.decode(newInitialProposalIdResult2, (uint256));

        // next, cast votes to get proposal to succeed
        _castVote(PHOGovernance, newInitialProposalId2, 1);

        // next, roll forward duration of proposal && queue
        vm.roll(proposalStartBlock + VOTING_PERIOD + 1);
        _queue(PHOGovernance, newInitialProposalId2);
        _execute(PHOGovernance, newInitialProposalId2);
        vm.stopPrank();
    }
}

interface IUSDC {
    function balanceOf(address account) external view returns (uint256);

    function mint(address to, uint256 amount) external;

    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address to, uint256 amount) external;

    function configureMinter(address minter, uint256 minterAllowedAmount) external;

    function masterMinter() external view returns (address);
}
