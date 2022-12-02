// File contracts/B.Protocol/CropJoinAdapter.sol
pragma solidity >=0.6.11 <0.9.0;

import "./CropJoin.sol";

// NOTE! - this is not an ERC20 token. transfer is not supported.
contract CropJoinAdapter is CropJoin {
    string public constant name = "B.AMM LUSD-ETH";
    string public constant symbol = "LUSDETH";
    uint256 public constant decimals = 18;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);

    constructor(address _lqty)
        public
        CropJoin(address(new Dummy()), "B.AMM", address(new DummyGem()), _lqty)
    {}

    // adapter to cropjoin
    function nav() public override returns (uint256) {
        return total;
    }

    function totalSupply() public view returns (uint256) {
        return total;
    }

    function balanceOf(address owner) public view returns (uint256 balance) {
        balance = stake[owner];
    }

    function mint(address to, uint256 value) internal virtual {
        join(to, value);
        emit Transfer(address(0), to, value);
    }

    function burn(address owner, uint256 value) internal virtual {
        exit(owner, value);
        emit Transfer(owner, address(0), value);
    }
}

contract Dummy {
    fallback() external {}
}

contract DummyGem is Dummy {
    function transfer(address, uint256) external pure returns (bool) {
        return true;
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        return true;
    }

    function decimals() external pure returns (uint256) {
        return 18;
    }
}
