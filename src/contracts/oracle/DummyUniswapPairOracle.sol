// SPDX-License-Identifier: MIT
pragma solidity >=0.6.11;

// import '../Uniswap/Interfaces/IUniswapV2Factory.sol';
// import '../Uniswap/Interfaces/IUniswapV2Pair.sol';
// import '../Math/FixedPoint.sol';
// import '../Uniswap/UniswapV2OracleLibrary.sol';
// import '../Uniswap/UniswapV2Library.sol';
import "openzeppelin-contracts/contracts/access/Ownable.sol";


/// @notice A dummy uniswap oracle for EUSD/WETH
// Fixed window oracle that recomputes the average price for the entire period once every period
// Note that the price average is only guaranteed to be over at least 1 period, but may be over a longer period
contract DummyUniswapPairOracle is Ownable {
    // using FixedPoint for *;
    
    address timelock_address;

    address public immutable token0;
    address public immutable token1;
    address public immutable token2;


    // uint    public price0CumulativeLast;
    uint    public price1CumulativeLast;
    uint    public price2CumulativeLast;

    // FixedPoint.uq112x112 public price0Average;
    // FixedPoint.uq112x112 public price1Average;

    modifier onlyByOwnGov() {
        require(msg.sender == owner() || msg.sender == timelock_address, "You are not an owner or the governance timelock");
        _;
    }

    /// TODO - replace this dummy contract with proper token pairs when working on oracle and uniswap pools
    /// tokenC is just here to make testing easier instead of deploying multiple oracles in the test set up for this sprint
    /// params tokenA - weth
    /// params tokenB - EUSD
    /// params tokenC - SHARE
    constructor (
        address tokenA, 
        address tokenB,
        address tokenC, 
        address _owner_address, 
        address _timelock_address
    ) {
        token0 = tokenA;
        token1 = tokenB;
        token2 = tokenC;
        // price0CumulativeLast = 1; // TODO - put whatever price I want to put for these early tests. Fetch the current accumulated price value (1 / 0)
        // price1CumulativeLast = 1; // TODO - put whatever price I want to put for these early tests. Fetch the current accumulated price value (1 / 0)

        timelock_address = _timelock_address;
    }

    function setTimelock(address _timelock_address) external onlyByOwnGov {
        timelock_address = _timelock_address;
    }

    }

    /// Note - for early tests, we will just feed a price param into this to get a price we want. This is temporary while we do not have our own uniswap oracle setup yet.
    /// Set it up only for EUSD --> but what price value am I looking for? What makes sense?
    /// future ref - the price of token0 is expressed in terms of token1/token0, while the price of token1 is expressed in terms of token0/token1
    /// params token to get price of
    /// params amountIn quantity of EUSD to measure
    /// returns amountOut price of EUSD vs eth
    function consult(address token, uint amountIn) public view returns (uint amountOut) {
        uint dummyPrice;
        require(amountIn != 0, "consult(): amountIn must be > 0");
        uint priceXCumulative;
         if (token == token1) {
            priceXCumulative = price1CumulativeLast;
        } else if (token == token2) {
            priceXCumulative = price2CumulativeLast;
        }
        dummyPrice = amountIn * priceXCumulative; // TODO - figure out what the price return should come out as... uint244, but what is a reasonable value?
        return dummyPrice;
    }

    /// @notice temporary function to set dummy price that is returned in consult()
    /// @dev token0 == weth, and we want prices wrt to token0, so we'll 
    function setDummyPrice(address token, uint price) public onlyByOwnGov returns (uint priceXCumulativeLast) {
        require(token == token1 || token == token2, "consult(): token not part of this pair");
        require(price != 0, "consult(): amountIn must be > 0");
        if (token == token1) {
            price1CumulativeLast = price;
            return price1CumulativeLast;
        } else if (token == token2) {
            price2CumulativeLast = price;
            return price2CumulativeLast;
        }
    }
}