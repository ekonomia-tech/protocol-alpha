/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import type { Provider, TransactionRequest } from "@ethersproject/providers";
import type { PromiseOrValue } from "../common";
import type { DummyOracle, DummyOracleInterface } from "../DummyOracle";

const _abi = [
  {
    inputs: [],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    inputs: [],
    name: "STETH_ADDRESS",
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
    name: "WETH_ADDRESS",
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
    name: "WSTETH_ADDRESS",
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
    name: "eth_pho_price",
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
    name: "eth_ton_price",
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
    name: "eth_usd_price",
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
    name: "getETHPHOPrice",
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
    name: "getETHTONPrice",
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
    name: "getETHUSDPrice",
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
    name: "getPHOUSDPrice",
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
    name: "getTONUSDPrice",
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
    name: "getUSDCUSDPrice",
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
    name: "getWethUSDPrice",
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
    name: "pho_usd_price",
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
        internalType: "uint256",
        name: "_price",
        type: "uint256",
      },
    ],
    name: "setETHPHOPrice",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "_price",
        type: "uint256",
      },
    ],
    name: "setETHTONPrice",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "_price",
        type: "uint256",
      },
    ],
    name: "setETHUSDPrice",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "_price",
        type: "uint256",
      },
    ],
    name: "setPHOUSDPrice",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "_price",
        type: "uint256",
      },
    ],
    name: "setTONUSDPrice",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "_price",
        type: "uint256",
      },
    ],
    name: "setUSDCUSDPrice",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "_price",
        type: "uint256",
      },
    ],
    name: "setWethUSDPrice",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "ton_usd_price",
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
    name: "usdc_usd_price",
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
    name: "weth_usd_price",
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
];

const _bytecode =
  "0x608060405234801561001057600080fd5b50685150ae84a8cdf0000060008181556377359400600155680ad78ebc5ac6200000600255686c6b935b8bbd400000600455620f42406003819055600581905560065560076020527f84c5ca2f7f2e4ca0122d358aebf0036d19214a8ecd3345e57129dbae0618d01882905573ae7ab96520de3a18e5e111b5eaab095312d7fe8490527f663a49f99094c48c8d89af07fbd81af2de876b0cca34334411da349b27f8102f819055600a906100c590600b610113565b6100cf9190610140565b737f39c581f595b53c5cb19bd0b3f8da6c935e2ca060005260076020527f94416004645a626907820dc10a83f0e7e82fe5572b44e84e877643ce205ff0ed55610162565b600081600019048311821515161561013b57634e487b7160e01b600052601160045260246000fd5b500290565b60008261015d57634e487b7160e01b600052601260045260246000fd5b500490565b6104e6806101716000396000f3fe608060405234801561001057600080fd5b506004361061018d5760003560e01c806369d87ab1116100de578063bb04265311610097578063d1cb15a511610071578063d1cb15a514610329578063dda78f5814610331578063dfed2e1414610344578063e454d1ac1461034c57600080fd5b8063bb04265314610305578063bf4b19901461030e578063ced657251461031657600080fd5b806369d87ab1146102a75780637985d7b4146102ba5780639dcb511a146102c2578063a3aca3f7146102e2578063ab627f95146102f5578063ae932611146102fd57600080fd5b80632947902d1161014b57806336e6372f1161012557806336e6372f1461024857806341976e091461026357806344984ac61461028c5780636908edac1461029f57600080fd5b80632947902d146102235780632a78b40614610236578063345ba24b1461023f57600080fd5b8062451d8b14610192578063040141e5146101ca578063057b8a91146101e557806312485d92146101fc57806315e98ba6146102055780631b859af71461020e575b600080fd5b6101ad73ae7ab96520de3a18e5e111b5eaab095312d7fe8481565b6040516001600160a01b0390911681526020015b60405180910390f35b6101ad73c02aaa39b223fe8d0a0e5c4f27ead9083c756cc281565b6101ee60055481565b6040519081526020016101c1565b6101ee60005481565b6101ee60025481565b61022161021c366004610418565b600455565b005b610221610231366004610418565b600355565b6101ee60065481565b6101ee60015481565b6101ad737f39c581f595b53c5cb19bd0b3f8da6c935e2ca081565b6101ee610271366004610431565b6001600160a01b031660009081526007602052604090205490565b61022161029a366004610418565b600555565b6000546101ee565b6102216102b5366004610418565b600155565b6006546101ee565b6101ee6102d0366004610431565b60076020526000908152604090205481565b6102216102f0366004610418565b600655565b6003546101ee565b6002546101ee565b6101ee60035481565b6001546101ee565b610221610324366004610418565b600255565b6004546101ee565b61022161033f366004610418565b610355565b6005546101ee565b6101ee60045481565b60076020527f84c5ca2f7f2e4ca0122d358aebf0036d19214a8ecd3345e57129dbae0618d01881905573ae7ab96520de3a18e5e111b5eaab095312d7fe846000527f663a49f99094c48c8d89af07fbd81af2de876b0cca34334411da349b27f8102f819055600a6103c782600b610461565b6103d1919061048e565b737f39c581f595b53c5cb19bd0b3f8da6c935e2ca0600090815260076020527f94416004645a626907820dc10a83f0e7e82fe5572b44e84e877643ce205ff0ed9190915555565b60006020828403121561042a57600080fd5b5035919050565b60006020828403121561044357600080fd5b81356001600160a01b038116811461045a57600080fd5b9392505050565b600081600019048311821515161561048957634e487b7160e01b600052601160045260246000fd5b500290565b6000826104ab57634e487b7160e01b600052601260045260246000fd5b50049056fea2646970667358221220859be9cff083bb67fd1f95078821480057be44cc2ed5e71f0b57323dd7e83eb064736f6c634300080d0033";

type DummyOracleConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: DummyOracleConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class DummyOracle__factory extends ContractFactory {
  constructor(...args: DummyOracleConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
  }

  override deploy(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<DummyOracle> {
    return super.deploy(overrides || {}) as Promise<DummyOracle>;
  }
  override getDeployTransaction(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(overrides || {});
  }
  override attach(address: string): DummyOracle {
    return super.attach(address) as DummyOracle;
  }
  override connect(signer: Signer): DummyOracle__factory {
    return super.connect(signer) as DummyOracle__factory;
  }

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): DummyOracleInterface {
    return new utils.Interface(_abi) as DummyOracleInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): DummyOracle {
    return new Contract(address, _abi, signerOrProvider) as DummyOracle;
  }
}
