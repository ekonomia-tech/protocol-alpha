/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import {
  Signer,
  utils,
  Contract,
  ContractFactory,
  BigNumberish,
  Overrides,
} from "ethers";
import type { Provider, TransactionRequest } from "@ethersproject/providers";
import type { PromiseOrValue } from "../common";
import type {
  ChainlinkPriceFeed,
  ChainlinkPriceFeedInterface,
} from "../ChainlinkPriceFeed";

const _abi = [
  {
    inputs: [
      {
        internalType: "uint256",
        name: "_precisionDifference",
        type: "uint256",
      },
    ],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "newToken",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "newFeed",
        type: "address",
      },
    ],
    name: "FeedAdded",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "removedToken",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "removedFeed",
        type: "address",
      },
    ],
    name: "FeedRemoved",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "previousOwner",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "newOwner",
        type: "address",
      },
    ],
    name: "OwnershipTransferred",
    type: "event",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "newToken",
        type: "address",
      },
      {
        internalType: "address",
        name: "newFeed",
        type: "address",
      },
    ],
    name: "addFeed",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "baseToken",
        type: "address",
      },
    ],
    name: "getPrice",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "owner",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "precisionDifference",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    name: "priceFeeds",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "feedToken",
        type: "address",
      },
    ],
    name: "removeFeed",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "renounceOwnership",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "newOwner",
        type: "address",
      },
    ],
    name: "transferOwnership",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
];

const _bytecode =
  "0x60a060405234801561001057600080fd5b5060405161099c38038061099c83398101604081905261002f916100e4565b61003833610094565b6000811161008c5760405162461bcd60e51b815260206004820181905260248201527f507269636520466565643a20707265636973696f6e206d757374206265203e30604482015260640160405180910390fd5b6080526100fd565b600080546001600160a01b038381166001600160a01b0319831681178455604051919092169283917f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e09190a35050565b6000602082840312156100f657600080fd5b5051919050565b60805161087e61011e6000396000818160e001526102a9015261087e6000f3fe608060405234801561001057600080fd5b50600436106100885760003560e01c8063715018a61161005b578063715018a6146101025780638da5cb5b1461010a5780639dcb511a1461012f578063f2fde38b1461015857600080fd5b806341976e091461008d5780634b90fd69146100b35780635853c627146100c85780636dbbd0f5146100db575b600080fd5b6100a061009b366004610628565b61016b565b6040519081526020015b60405180910390f35b6100c66100c1366004610628565b6102e0565b005b6100c66100d6366004610643565b6103ce565b6100a07f000000000000000000000000000000000000000000000000000000000000000081565b6100c66104d5565b6000546001600160a01b03165b6040516001600160a01b0390911681526020016100aa565b61011761013d366004610628565b6001602052600090815260409020546001600160a01b031681565b6100c6610166366004610628565b6104e9565b6001600160a01b038181166000908152600160205260408120549091166101d95760405162461bcd60e51b815260206004820152601f60248201527f507269636520466565643a2066656564206e6f7420726567697374657265640060448201526064015b60405180910390fd5b6001600160a01b03808316600090815260016020526040808220548151633fabe5a360e21b815291519293169163feaf968c9160048082019260a0929091908290030181865afa158015610231573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906102559190610690565b50505091505060008112156102a45760405162461bcd60e51b81526020600482015260156024820152740507269636520466565643a207072696365203c203605c1b60448201526064016101d0565b6102cf7f0000000000000000000000000000000000000000000000000000000000000000600a6107dc565b6102d990826107e8565b9392505050565b6102e8610562565b6001600160a01b03811661030e5760405162461bcd60e51b81526004016101d090610807565b6001600160a01b03818116600090815260016020526040902054166103755760405162461bcd60e51b815260206004820152601f60248201527f507269636520466565643a2066656564206e6f7420726567697374657265640060448201526064016101d0565b6001600160a01b0380821660008181526001602052604080822080546001600160a01b0319811690915590519316928392917fa551ef23eb9f5fcdfd41e19414c3eed81c9412d63fa26c01f3902c6431e1950d91a35050565b6103d6610562565b6001600160a01b038116158015906103f657506001600160a01b03821615155b6104125760405162461bcd60e51b81526004016101d090610807565b6001600160a01b0382811660009081526001602052604090205481831691160361047e5760405162461bcd60e51b815260206004820152601b60248201527f507269636520466565643a20666565642072656769737465726564000000000060448201526064016101d0565b6001600160a01b0382811660008181526001602052604080822080546001600160a01b0319169486169485179055517f037e7fb95c491187e3e2fbb914fac34809e73da6bfe5119bb916b263fb6013059190a35050565b6104dd610562565b6104e760006105bc565b565b6104f1610562565b6001600160a01b0381166105565760405162461bcd60e51b815260206004820152602660248201527f4f776e61626c653a206e6577206f776e657220697320746865207a65726f206160448201526564647265737360d01b60648201526084016101d0565b61055f816105bc565b50565b6000546001600160a01b031633146104e75760405162461bcd60e51b815260206004820181905260248201527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e657260448201526064016101d0565b600080546001600160a01b038381166001600160a01b0319831681178455604051919092169283917f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e09190a35050565b80356001600160a01b038116811461062357600080fd5b919050565b60006020828403121561063a57600080fd5b6102d98261060c565b6000806040838503121561065657600080fd5b61065f8361060c565b915061066d6020840161060c565b90509250929050565b805169ffffffffffffffffffff8116811461062357600080fd5b600080600080600060a086880312156106a857600080fd5b6106b186610676565b94506020860151935060408601519250606086015191506106d460808701610676565b90509295509295909350565b634e487b7160e01b600052601160045260246000fd5b600181815b80851115610731578160001904821115610717576107176106e0565b8085161561072457918102915b93841c93908002906106fb565b509250929050565b600082610748575060016107d6565b81610755575060006107d6565b816001811461076b576002811461077557610791565b60019150506107d6565b60ff841115610786576107866106e0565b50506001821b6107d6565b5060208310610133831016604e8410600b84101617156107b4575081810a6107d6565b6107be83836106f6565b80600019048211156107d2576107d26106e0565b0290505b92915050565b60006102d98383610739565b6000816000190483118215151615610802576108026106e0565b500290565b60208082526021908201527f507269636520466565643a207a65726f206164647265737320646574656374656040820152601960fa1b60608201526080019056fea2646970667358221220b285e7ab4e25a637d3b62f8a2997ab476cba90b2543604f9e3c94a770b7f40c764736f6c634300080d0033";

type ChainlinkPriceFeedConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: ChainlinkPriceFeedConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class ChainlinkPriceFeed__factory extends ContractFactory {
  constructor(...args: ChainlinkPriceFeedConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
  }

  override deploy(
    _precisionDifference: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ChainlinkPriceFeed> {
    return super.deploy(
      _precisionDifference,
      overrides || {}
    ) as Promise<ChainlinkPriceFeed>;
  }
  override getDeployTransaction(
    _precisionDifference: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(_precisionDifference, overrides || {});
  }
  override attach(address: string): ChainlinkPriceFeed {
    return super.attach(address) as ChainlinkPriceFeed;
  }
  override connect(signer: Signer): ChainlinkPriceFeed__factory {
    return super.connect(signer) as ChainlinkPriceFeed__factory;
  }

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): ChainlinkPriceFeedInterface {
    return new utils.Interface(_abi) as ChainlinkPriceFeedInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): ChainlinkPriceFeed {
    return new Contract(address, _abi, signerOrProvider) as ChainlinkPriceFeed;
  }
}