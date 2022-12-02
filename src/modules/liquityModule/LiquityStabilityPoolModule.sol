pragma solidity ^0.8.13;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./dependencies/CropJoinAdapter.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IStabilityPool.sol";

// INSPIRED BY B.Protocol - https://etherscan.deth.net/address/0x00FF66AB8699AAfa050EE5EF5041D1503aa0849a
contract LiquityStabilityPoolModule is CropJoinAdapter {
    using SafeMath for uint256;

    AggregatorV3Interface public immutable priceAggregator;
    AggregatorV3Interface public immutable lusd2UsdPriceAggregator;
    IERC20 public immutable LUSD;
    IStabilityPool public immutable SP;

    // address payable public immutable feePool;
    // uint public constant MAX_FEE = 100; // 1%
    // uint public fee = 0; // fee in bps
    // uint public A = 20;
    // uint public constant MIN_A = 20;
    // uint public constant MAX_A = 200;

    // uint public immutable maxDiscount; // max discount in bips

    address public immutable frontEndTag;

    uint256 public constant PRECISION = 1e18;

    // event ParamsSet(uint A, uint fee);
    event UserDeposit(address indexed user, uint256 lusdAmount, uint256 numShares);
    event UserWithdraw(
        address indexed user, uint256 lusdAmount, uint256 ethAmount, uint256 numShares
    );

    constructor(
        address _priceAggregator,
        address _lusd2UsdPriceAggregator,
        address payable _SP,
        address _LUSD,
        address _LQTY,
        uint256 _maxDiscount,
        address payable _feePool,
        address _fronEndTag
    ) public CropJoinAdapter(_LQTY) {
        priceAggregator = AggregatorV3Interface(_priceAggregator);
        lusd2UsdPriceAggregator = AggregatorV3Interface(_lusd2UsdPriceAggregator);
        LUSD = IERC20(_LUSD);
        SP = IStabilityPool(_SP);

        // feePool = _feePool;
        // maxDiscount = _maxDiscount;
        frontEndTag = _fronEndTag; // DK - might not need TODO
    }

    // DK - don't think we need this
    // function setParams(uint _A, uint _fee) external onlyOwner {
    //     require(_fee <= MAX_FEE, "setParams: fee is too big");
    //     require(_A >= MIN_A, "setParams: A too small");
    //     require(_A <= MAX_A, "setParams: A too big");

    //     fee = _fee;
    //     A = _A;

    //     emit ParamsSet(_A, _fee);
    // }

    function fetchPrice() public view returns (uint256) {
        uint256 chainlinkDecimals;
        uint256 chainlinkLatestAnswer;
        uint256 chainlinkTimestamp;

        // First, try to get current decimal precision:
        try priceAggregator.decimals() returns (uint8 decimals) {
            // If call to Chainlink succeeds, record the current decimal precision
            chainlinkDecimals = decimals;
        } catch {
            // If call to Chainlink aggregator reverts, return a zero response with success = false
            return 0;
        }

        // Secondly, try to get latest price data:
        try priceAggregator.latestRoundData() returns (
            uint80, /* roundId */
            int256 answer,
            uint256, /* startedAt */
            uint256 timestamp,
            uint80 /* answeredInRound */
        ) {
            // If call to Chainlink succeeds, return the response and success = true
            chainlinkLatestAnswer = uint256(answer);
            chainlinkTimestamp = timestamp;
        } catch {
            // If call to Chainlink aggregator reverts, return a zero response with success = false
            return 0;
        }

        if (chainlinkTimestamp + 1 hours < block.timestamp) return 0; // price is down

        uint256 chainlinkFactor = 10 ** chainlinkDecimals;
        return chainlinkLatestAnswer.mul(PRECISION) / chainlinkFactor;
    }

    // NOTE - instead of stakeFor() right now - DK.... unsure if it should be 2 separate contracts, AMO and Module
    function deposit(uint256 lusdAmount) external {
        // update share
        uint256 lusdValue = SP.getCompoundedLUSDDeposit(address(this));
        uint256 ethValue = SP.getDepositorETHGain(address(this)).add(address(this).balance);

        uint256 price = fetchPrice();
        require(ethValue == 0 || price > 0, "deposit: chainlink is down");

        uint256 totalValue = lusdValue.add(ethValue.mul(price) / PRECISION);

        // this is in theory not reachable. if it is, better halt deposits
        // the condition is equivalent to: (totalValue = 0) ==> (total = 0)
        require(totalValue > 0 || total == 0, "deposit: system is rekt");

        uint256 newShare = PRECISION;
        if (total > 0) newShare = total.mul(lusdAmount) / totalValue;

        // deposit
        require(
            LUSD.transferFrom(msg.sender, address(this), lusdAmount), "deposit: transferFrom failed"
        );
        SP.provideToSP(lusdAmount, frontEndTag);

        // update LP token
        mint(msg.sender, newShare);

        emit UserDeposit(msg.sender, lusdAmount, newShare);
    }

    // NOTE - instead of withdrawFor() right now - DK.... unsure if it should be 2 separate contracts, AMO and Module
    function withdraw(uint256 numShares) external {
        uint256 lusdValue = SP.getCompoundedLUSDDeposit(address(this));
        uint256 ethValue = SP.getDepositorETHGain(address(this)).add(address(this).balance);

        uint256 lusdAmount = lusdValue.mul(numShares).div(total);
        uint256 ethAmount = ethValue.mul(numShares).div(total);

        // this withdraws lusd, lqty, and eth.
        SP.withdrawFromSP(lusdAmount);

        // update LP token
        // this function has LQTY sent if you look at CropJoin.sol code
        burn(msg.sender, numShares);

        // send lusd and eth
        if (lusdAmount > 0) LUSD.transfer(msg.sender, lusdAmount);
        if (ethAmount > 0) {
            (bool success,) = msg.sender.call{value: ethAmount}(""); // re-entry is fine here
            require(success, "withdraw: sending ETH failed");
        }

        emit UserWithdraw(msg.sender, lusdAmount, ethAmount, numShares);
    }
}
