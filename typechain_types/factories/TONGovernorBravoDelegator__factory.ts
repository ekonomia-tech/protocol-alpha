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
  TONGovernorBravoDelegator,
  TONGovernorBravoDelegatorInterface,
} from "../TONGovernorBravoDelegator";

const _abi = [
  {
    inputs: [
      {
        internalType: "address",
        name: "timelock_",
        type: "address",
      },
      {
        internalType: "address",
        name: "ton_",
        type: "address",
      },
      {
        internalType: "address",
        name: "admin_",
        type: "address",
      },
      {
        internalType: "address",
        name: "implementation_",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "votingPeriod_",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "votingDelay_",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "proposalThreshold_",
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
        indexed: false,
        internalType: "address",
        name: "oldAdmin",
        type: "address",
      },
      {
        indexed: false,
        internalType: "address",
        name: "newAdmin",
        type: "address",
      },
    ],
    name: "NewAdmin",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "oldImplementation",
        type: "address",
      },
      {
        indexed: false,
        internalType: "address",
        name: "newImplementation",
        type: "address",
      },
    ],
    name: "NewImplementation",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "oldPendingAdmin",
        type: "address",
      },
      {
        indexed: false,
        internalType: "address",
        name: "newPendingAdmin",
        type: "address",
      },
    ],
    name: "NewPendingAdmin",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "id",
        type: "uint256",
      },
    ],
    name: "ProposalCanceled",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "id",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address",
        name: "proposer",
        type: "address",
      },
      {
        indexed: false,
        internalType: "address[]",
        name: "targets",
        type: "address[]",
      },
      {
        indexed: false,
        internalType: "uint256[]",
        name: "values",
        type: "uint256[]",
      },
      {
        indexed: false,
        internalType: "string[]",
        name: "signatures",
        type: "string[]",
      },
      {
        indexed: false,
        internalType: "bytes[]",
        name: "calldatas",
        type: "bytes[]",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "startBlock",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "endBlock",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "string",
        name: "description",
        type: "string",
      },
    ],
    name: "ProposalCreated",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "id",
        type: "uint256",
      },
    ],
    name: "ProposalExecuted",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "id",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "eta",
        type: "uint256",
      },
    ],
    name: "ProposalQueued",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "oldProposalThreshold",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "newProposalThreshold",
        type: "uint256",
      },
    ],
    name: "ProposalThresholdSet",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "voter",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "proposalId",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint8",
        name: "support",
        type: "uint8",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "votes",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "string",
        name: "reason",
        type: "string",
      },
    ],
    name: "VoteCast",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "oldVotingDelay",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "newVotingDelay",
        type: "uint256",
      },
    ],
    name: "VotingDelaySet",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "oldVotingPeriod",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "newVotingPeriod",
        type: "uint256",
      },
    ],
    name: "VotingPeriodSet",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "account",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "expiration",
        type: "uint256",
      },
    ],
    name: "WhitelistAccountExpirationSet",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "oldGuardian",
        type: "address",
      },
      {
        indexed: false,
        internalType: "address",
        name: "newGuardian",
        type: "address",
      },
    ],
    name: "WhitelistGuardianSet",
    type: "event",
  },
  {
    stateMutability: "payable",
    type: "fallback",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "implementation_",
        type: "address",
      },
    ],
    name: "_setImplementation",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "admin",
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
    name: "implementation",
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
    name: "pendingAdmin",
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
];

const _bytecode =
  "0x608060405234801561001057600080fd5b506040516106d93803806106d983398101604081905261002f916102c2565b600080546001600160a01b031916331790556040516001600160a01b03888116602483015287166044820152606481018490526084810183905260a481018290526100ac90859060c40160408051601f198184030181529190526020810180516001600160e01b0390811663344fe42d60e21b179091526100e216565b6100b584610155565b5050600080546001600160a01b0319166001600160a01b0394909416939093179092555061036e92505050565b600080836001600160a01b0316836040516100fd9190610333565b600060405180830381855af49150503d8060008114610138576040519150601f19603f3d011682016040523d82523d6000602084013e61013d565b606091505b5090925090508161014f573d60208201fd5b50505050565b6000546001600160a01b031633146101c85760405162461bcd60e51b815260206004820152603660248201526000805160206106b983398151915260448201527f656d656e746174696f6e3a2061646d696e206f6e6c790000000000000000000060648201526084015b60405180910390fd5b6001600160a01b0381166102455760405162461bcd60e51b815260206004820152604a60248201526000805160206106b983398151915260448201527f656d656e746174696f6e3a20696e76616c696420696d706c656d656e746174696064820152696f6e206164647265737360b01b608482015260a4016101bf565b600280546001600160a01b038381166001600160a01b031983168117909355604080519190921680825260208201939093527fd604de94d45953f9138079ec1b82d533cb2160c906d1076d1f7ed54befbca97a910160405180910390a15050565b80516001600160a01b03811681146102bd57600080fd5b919050565b600080600080600080600060e0888a0312156102dd57600080fd5b6102e6886102a6565b96506102f4602089016102a6565b9550610302604089016102a6565b9450610310606089016102a6565b93506080880151925060a0880151915060c0880151905092959891949750929550565b6000825160005b81811015610354576020818601810151858301520161033a565b81811115610363576000828501525b509190910192915050565b61033c8061037d6000396000f3fe60806040526004361061003f5760003560e01c806326782247146100bc5780635c60da1b146100f8578063bb913f4114610118578063f851a44014610138575b6002546040516000916001600160a01b03169061005f90839036906102c6565b600060405180830381855af49150503d806000811461009a576040519150601f19603f3d011682016040523d82523d6000602084013e61009f565b606091505b505090506040513d6000823e8180156100b6573d82f35b3d82fd5b005b3480156100c857600080fd5b506001546100dc906001600160a01b031681565b6040516001600160a01b03909116815260200160405180910390f35b34801561010457600080fd5b506002546100dc906001600160a01b031681565b34801561012457600080fd5b506100ba6101333660046102d6565b610158565b34801561014457600080fd5b506000546100dc906001600160a01b031681565b6000546001600160a01b031633146101d65760405162461bcd60e51b815260206004820152603660248201527f476f7665726e6f72427261766f44656c656761746f723a3a5f736574496d706c604482015275656d656e746174696f6e3a2061646d696e206f6e6c7960501b60648201526084015b60405180910390fd5b6001600160a01b0381166102655760405162461bcd60e51b815260206004820152604a60248201527f476f7665726e6f72427261766f44656c656761746f723a3a5f736574496d706c60448201527f656d656e746174696f6e3a20696e76616c696420696d706c656d656e746174696064820152696f6e206164647265737360b01b608482015260a4016101cd565b600280546001600160a01b038381166001600160a01b031983168117909355604080519190921680825260208201939093527fd604de94d45953f9138079ec1b82d533cb2160c906d1076d1f7ed54befbca97a910160405180910390a15050565b8183823760009101908152919050565b6000602082840312156102e857600080fd5b81356001600160a01b03811681146102ff57600080fd5b939250505056fea26469706673582212205a15326eaaa7c4f443480837784bbd32d8bc2bcc53ac006c031ac2cb2d6c33ea64736f6c634300080d0033476f7665726e6f72427261766f44656c656761746f723a3a5f736574496d706c";

type TONGovernorBravoDelegatorConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: TONGovernorBravoDelegatorConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class TONGovernorBravoDelegator__factory extends ContractFactory {
  constructor(...args: TONGovernorBravoDelegatorConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
  }

  override deploy(
    timelock_: PromiseOrValue<string>,
    ton_: PromiseOrValue<string>,
    admin_: PromiseOrValue<string>,
    implementation_: PromiseOrValue<string>,
    votingPeriod_: PromiseOrValue<BigNumberish>,
    votingDelay_: PromiseOrValue<BigNumberish>,
    proposalThreshold_: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<TONGovernorBravoDelegator> {
    return super.deploy(
      timelock_,
      ton_,
      admin_,
      implementation_,
      votingPeriod_,
      votingDelay_,
      proposalThreshold_,
      overrides || {}
    ) as Promise<TONGovernorBravoDelegator>;
  }
  override getDeployTransaction(
    timelock_: PromiseOrValue<string>,
    ton_: PromiseOrValue<string>,
    admin_: PromiseOrValue<string>,
    implementation_: PromiseOrValue<string>,
    votingPeriod_: PromiseOrValue<BigNumberish>,
    votingDelay_: PromiseOrValue<BigNumberish>,
    proposalThreshold_: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(
      timelock_,
      ton_,
      admin_,
      implementation_,
      votingPeriod_,
      votingDelay_,
      proposalThreshold_,
      overrides || {}
    );
  }
  override attach(address: string): TONGovernorBravoDelegator {
    return super.attach(address) as TONGovernorBravoDelegator;
  }
  override connect(signer: Signer): TONGovernorBravoDelegator__factory {
    return super.connect(signer) as TONGovernorBravoDelegator__factory;
  }

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): TONGovernorBravoDelegatorInterface {
    return new utils.Interface(_abi) as TONGovernorBravoDelegatorInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): TONGovernorBravoDelegator {
    return new Contract(
      address,
      _abi,
      signerOrProvider
    ) as TONGovernorBravoDelegator;
  }
}
