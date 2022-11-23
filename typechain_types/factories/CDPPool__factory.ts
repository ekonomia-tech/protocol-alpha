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
import type { CDPPool, CDPPoolInterface } from "../CDPPool";

const _abi = [
  {
    inputs: [
      {
        internalType: "address",
        name: "_moduleManager",
        type: "address",
      },
      {
        internalType: "address",
        name: "_priceOracle",
        type: "address",
      },
      {
        internalType: "address",
        name: "_collateral",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "_minCR",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "_liquidationCR",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "_minDebt",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "_protocolFee",
        type: "uint256",
      },
    ],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    inputs: [],
    name: "CDPAlreadyActive",
    type: "error",
  },
  {
    inputs: [],
    name: "CDPNotActive",
    type: "error",
  },
  {
    inputs: [],
    name: "CRTooLow",
    type: "error",
  },
  {
    inputs: [],
    name: "DebtTooLow",
    type: "error",
  },
  {
    inputs: [],
    name: "FullAmountNotPresent",
    type: "error",
  },
  {
    inputs: [],
    name: "MinDebtNotMet",
    type: "error",
  },
  {
    inputs: [],
    name: "NotInLiquidationZone",
    type: "error",
  },
  {
    inputs: [],
    name: "ValueNotInRange",
    type: "error",
  },
  {
    inputs: [],
    name: "ZeroAddress",
    type: "error",
  },
  {
    inputs: [],
    name: "ZeroValue",
    type: "error",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "user",
        type: "address",
      },
    ],
    name: "Closed",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "addedCollateral",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "collateral",
        type: "uint256",
      },
    ],
    name: "CollateralAdded",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "removedCollateral",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "collateralLeft",
        type: "uint256",
      },
    ],
    name: "CollateralRemoved",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "addedDebt",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "debt",
        type: "uint256",
      },
    ],
    name: "DebtAdded",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "removedDebt",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "debt",
        type: "uint256",
      },
    ],
    name: "DebtRemoved",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "liquidator",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "paidToLiquidator",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "debt",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "collateralLiquidated",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "repaidToDebtor",
        type: "uint256",
      },
    ],
    name: "Liquidated",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "debt",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "collateral",
        type: "uint256",
      },
    ],
    name: "Opened",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "amountWithdrawn",
        type: "uint256",
      },
    ],
    name: "WithdrawFees",
    type: "event",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "_collateralAmount",
        type: "uint256",
      },
    ],
    name: "addCollateral",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_user",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "_collateralAmount",
        type: "uint256",
      },
    ],
    name: "addCollateralFor",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "_debtAmount",
        type: "uint256",
      },
    ],
    name: "addDebt",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "calculateLiquidationFee",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "pure",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "calculateProtocolFee",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
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
    name: "cdps",
    outputs: [
      {
        internalType: "uint256",
        name: "debt",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "collateral",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "close",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "collateral",
    outputs: [
      {
        internalType: "contract IERC20Metadata",
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
        internalType: "uint256",
        name: "_amount",
        type: "uint256",
      },
    ],
    name: "collateralToUSD",
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
        name: "_collateralAmount",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "_debtAmount",
        type: "uint256",
      },
    ],
    name: "computeCR",
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
        name: "_debt",
        type: "uint256",
      },
    ],
    name: "debtToCollateral",
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
    name: "feesCollected",
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
    name: "getCollateralUSDTotal",
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
        name: "_user",
        type: "address",
      },
    ],
    name: "liquidate",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "liquidationCR",
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
    name: "minCR",
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
    name: "minDebt",
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
    name: "moduleManager",
    outputs: [
      {
        internalType: "contract IModuleManager",
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
        internalType: "uint256",
        name: "_collateralAmount",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "_debtAmount",
        type: "uint256",
      },
    ],
    name: "open",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_user",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "_collateralAmount",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "_debtAmount",
        type: "uint256",
      },
    ],
    name: "openFor",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "pool",
    outputs: [
      {
        internalType: "uint256",
        name: "debt",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "collateral",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "priceOracle",
    outputs: [
      {
        internalType: "contract IPriceOracle",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "protocolFee",
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
        name: "_collateralAmount",
        type: "uint256",
      },
    ],
    name: "removeCollateral",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_user",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "_collateralAmount",
        type: "uint256",
      },
    ],
    name: "removeCollateralFor",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "_debt",
        type: "uint256",
      },
    ],
    name: "removeDebt",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "withdrawFees",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
];

const _bytecode =
  "0x60a06040523480156200001157600080fd5b506040516200193f3803806200193f83398101604081905262000034916200015b565b6001600160a01b03871615806200005257506001600160a01b038616155b806200006557506001600160a01b038516155b15620000845760405163d92e233d60e01b815260040160405180910390fd5b620186a084111580620000995750620186a081115b80620000a55750838310155b15620000c457604051633759768360e21b815260040160405180910390fd5b811580620000d0575080155b15620000ef57604051637c946ed760e01b815260040160405180910390fd5b600080546001600160a01b03199081166001600160a01b03998a1617909155600180549091169688169690961790955592909416608052600255600392909255600491909155600555620001cc565b80516001600160a01b03811681146200015657600080fd5b919050565b600080600080600080600060e0888a0312156200017757600080fd5b62000182886200013e565b965062000192602089016200013e565b9550620001a2604089016200013e565b9450606088015193506080880151925060a0880151915060c0880151905092959891949750929550565b60805161171f620002206000396000818161037c015281816103d901528181610626015281816106ca015281816108ff01528181610eb501528181611048015281816111e3015261136b015261171f6000f3fe608060405234801561001057600080fd5b50600436106101a95760003560e01c806372b39532116100f9578063b0e21e8a11610097578063d8dfeb4511610071578063d8dfeb4514610377578063f071db5a1461039e578063f17336d7146103a7578063f4bcb686146103b057600080fd5b8063b0e21e8a14610348578063bcc46e8314610351578063c57df8431461036457600080fd5b806384837dc5116100d357806384837dc5146102fc57806395e36f4d1461030f5780639c7c270c146103225780639c9b855a1461033557600080fd5b806372b39532146102ba578063784c2392146102cd578063840c7e24146102d557600080fd5b80633237c15811610166578063476343ee11610140578063476343ee146101c15780634de21f661461028b57806362f256e71461029e57806365932382146102b157600080fd5b80633237c1581461025d5780634082de671461027057806343d726d61461028357600080fd5b80630769d7a2146101ae57806316f0115b146101c3578063170441c5146101eb5780631738675f1461020c5780632630c12f1461021f5780632f8655681461024a575b600080fd5b6101c16101bc36600461145f565b6103b9565b005b6007546008546101d1919082565b604080519283526020830191909152015b60405180910390f35b6101fe6101f9366004611492565b6103c9565b6040519081526020016101e2565b6101fe61021a3660046114ab565b61047f565b600154610232906001600160a01b031681565b6040516001600160a01b0390911681526020016101e2565b6101c16102583660046114cd565b6104af565b6101c161026b366004611492565b6107ee565b6101c161027e3660046114ab565b6107fb565b6101c161080a565b6101c1610299366004611492565b6109f9565b6101fe6102ac366004611492565b610bb3565b6101fe60035481565b600054610232906001600160a01b031681565b6101fe610bcf565b6101d16102e33660046114cd565b6009602052600090815260409020805460019091015482565b6101c161030a366004611492565b610be4565b6101c161031d3660046114e8565b610d36565b6101d1610330366004611492565b610d40565b6101c16103433660046114e8565b610d7b565b6101fe60055481565b6101c161035f366004611492565b610d85565b6101fe610372366004611492565b610d8f565b6102327f000000000000000000000000000000000000000000000000000000000000000081565b6101fe60065481565b6101fe60045481565b6101fe60025481565b6103c4838383610daf565b505050565b6000806103d461102e565b9050807f00000000000000000000000000000000000000000000000000000000000000006001600160a01b031663313ce5676040518163ffffffff1660e01b8152600401602060405180830381865afa158015610435573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906104599190611512565b61046490600a61162f565b61046e908561163e565b610478919061165d565b9392505050565b60008061048b84610d8f565b90508261049b620186a08361163e565b6104a5919061165d565b9150505b92915050565b6001600160a01b038116600090815260096020526040812080549091036104e9576040516350e0b0bd60e11b815260040160405180910390fd5b60006104fd8260010154836000015461047f565b9050600354811061052157604051630d28662f60e41b815260040160405180910390fd5b81546007805460009061053590849061167f565b909155505060018201546008805460009061055190849061167f565b925050819055506000806105688460010154610d40565b91509150600061057782610bb3565b9050600061058886600001546103c9565b905060006105968383611696565b905060006105a4828661167f565b6000548954604051637bd55cfd60e01b815233600482015260248101919091529192506001600160a01b031690637bd55cfd90604401600060405180830381600087803b1580156105f457600080fd5b505af1158015610608573d6000803e3d6000fd5b505060405163a9059cbb60e01b8152336004820152602481018590527f00000000000000000000000000000000000000000000000000000000000000006001600160a01b0316925063a9059cbb91506044016020604051808303816000875af1158015610679573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061069d91906116ae565b5080156107395760405163a9059cbb60e01b81526001600160a01b038a81166004830152602482018390527f0000000000000000000000000000000000000000000000000000000000000000169063a9059cbb906044016020604051808303816000875af1158015610713573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061073791906116ae565b505b875460018901546040805185815260208101939093528201526060810182905233906001600160a01b038b16907f81749dfaca15de9da21f7b95c96f27ca0cd78a345932577022746848573cb8619060800160405180910390a361079c866110bd565b6001600160a01b038916600081815260096020526040808220828155600101829055517f13607bf9d2dd20e1f3a7daf47ab12856f8aad65e6ae7e2c75ace3d0c424a40e89190a2505050505050505050565b6107f833826110d1565b50565b610806338383610daf565b5050565b336000908152600960205260408120805490910361083b576040516350e0b0bd60e11b815260040160405180910390fd5b6000548154604051637bd55cfd60e01b815233600482015260248101919091526001600160a01b0390911690637bd55cfd90604401600060405180830381600087803b15801561088a57600080fd5b505af115801561089e573d6000803e3d6000fd5b5050505060006108b18260000154610d40565b50905060006108bf826103c9565b90508260000154600760000160008282546108da919061167f565b90915550506001830154600880546000906108f690849061167f565b925050819055507f00000000000000000000000000000000000000000000000000000000000000006001600160a01b031663a9059cbb3383866001015461093d919061167f565b6040516001600160e01b031960e085901b1681526001600160a01b03909216600483015260248201526044016020604051808303816000875af1158015610988573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906109ac91906116ae565b506109b6816110bd565b33600081815260096020526040808220828155600101829055517f13607bf9d2dd20e1f3a7daf47ab12856f8aad65e6ae7e2c75ace3d0c424a40e89190a2505050565b80600003610a1a57604051637c946ed760e01b815260040160405180910390fd5b3360009081526009602052604081208054909103610a4b576040516350e0b0bd60e11b815260040160405180910390fd5b6004548154610a5b90849061167f565b1015610a7a576040516345971e5960e01b815260040160405180910390fd5b6000610a8583610d40565b5090506000610a93826103c9565b600054604051637bd55cfd60e01b8152336004820152602481018790529192506001600160a01b031690637bd55cfd90604401600060405180830381600087803b158015610ae057600080fd5b505af1158015610af4573d6000803e3d6000fd5b5050505083836000016000828254610b0c919061167f565b9250508190555080836001016000828254610b27919061167f565b909155505060078054859190600090610b4190849061167f565b909155505060088054829190600090610b5b90849061167f565b90915550610b6a9050816110bd565b825460405133917f197855539a2f22c7081f60e389b4e22562163667264ea1cd5b6e1a1d440e7d3791610ba591888252602082015260400190565b60405180910390a250505050565b6000620186a0610bc56113888461163e565b6104a9919061165d565b6000610bdf600760010154610d8f565b905090565b80600003610c0557604051637c946ed760e01b815260040160405180910390fd5b3360009081526009602052604081208054909103610c36576040516350e0b0bd60e11b815260040160405180910390fd5b8054600090610c46908490611696565b90506000610c5883600101548361047f565b9050600254811015610c7d5760405163513fbea360e01b815260040160405180910390fd5b60005460405163391b114160e01b8152336004820152602481018690526001600160a01b039091169063391b114190604401600060405180830381600087803b158015610cc957600080fd5b505af1158015610cdd573d6000803e3d6000fd5b505050508360076000016000828254610cf69190611696565b9091555050818355604080518581526020810184905233917fa93cbece04e2e5bc20185a6e9c8f567df97191e2b0c1f5dc6ea2fe2921e1a06d9101610ba5565b61080682826110d1565b6000806000620186a060055485610d57919061163e565b610d61919061165d565b90506000610d6f828661167f565b91959194509092505050565b61080682826112a8565b6107f833826112a8565b600080610d9a61102e565b9050670de0b6b3a764000061046e828561163e565b6001600160a01b038316610dd65760405163d92e233d60e01b815260040160405180910390fd5b811580610de1575080155b15610dff57604051637c946ed760e01b815260040160405180910390fd5b600454811015610e2257604051636457a1f360e01b815260040160405180910390fd5b6001600160a01b03831660009081526009602052604090205415610e58576040516260812d60e91b815260040160405180910390fd5b6000610e64838361047f565b9050600254811015610e895760405163513fbea360e01b815260040160405180910390fd5b6040516323b872dd60e01b81526001600160a01b038581166004830152306024830152604482018590527f000000000000000000000000000000000000000000000000000000000000000016906323b872dd906064016020604051808303816000875af1158015610efe573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190610f2291906116ae565b5060408051808201825283815260208082018681526001600160a01b03888116600081815260099094528584209451855591516001909401939093559054925163391b114160e01b815260048101919091526024810185905291169063391b114190604401600060405180830381600087803b158015610fa157600080fd5b505af1158015610fb5573d6000803e3d6000fd5b505050508160076000016000828254610fce9190611696565b909155505060088054849190600090610fe8908490611696565b909155505060408051838152602081018590526001600160a01b038616917f0e00eb3434eeed137478dadba5581f87fdda6f16b438d9d1b616b24093bfbb429101610ba5565b6001546040516341976e0960e01b81526001600160a01b037f00000000000000000000000000000000000000000000000000000000000000008116600483015260009216906341976e0990602401602060405180830381865afa158015611099573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190610bdf91906116d0565b806006546110cb9190611696565b60065550565b6001600160a01b0382166110f85760405163d92e233d60e01b815260040160405180910390fd5b8060000361111957604051637c946ed760e01b815260040160405180910390fd5b6001600160a01b03821660009081526009602052604081208054909103611153576040516350e0b0bd60e11b815260040160405180910390fd5b6000828260010154611165919061167f565b9050600061117782846000015461047f565b905060025481101561119c5760405163513fbea360e01b815260040160405180910390fd5b60018301829055600880548591906000906111b890849061167f565b909155505060405163a9059cbb60e01b81526001600160a01b038681166004830152602482018690527f0000000000000000000000000000000000000000000000000000000000000000169063a9059cbb906044016020604051808303816000875af115801561122c573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061125091906116ae565b50846001600160a01b03167f47e1336b6fdb5f42c3a1d28b558fa98786d820c3705d726358dcc8e63a401eef858560010154604051611299929190918252602082015260400190565b60405180910390a25050505050565b6001600160a01b0382166112cf5760405163d92e233d60e01b815260040160405180910390fd5b806000036112f057604051637c946ed760e01b815260040160405180910390fd5b6001600160a01b0382166000908152600960205260408120805490910361132a576040516350e0b0bd60e11b815260040160405180910390fd5b600082826001015461133c9190611696565b6040516323b872dd60e01b81526001600160a01b038681166004830152306024830152604482018690529192507f0000000000000000000000000000000000000000000000000000000000000000909116906323b872dd906064016020604051808303816000875af11580156113b6573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906113da91906116ae565b5060018201819055600880548491906000906113f7908490611696565b909155505060018201546040516001600160a01b038616917f11f8990ac38271f23dea447d5728e9914fca7cea2edda43af6c43c415f8bc30b91610ba591878252602082015260400190565b80356001600160a01b038116811461145a57600080fd5b919050565b60008060006060848603121561147457600080fd5b61147d84611443565b95602085013595506040909401359392505050565b6000602082840312156114a457600080fd5b5035919050565b600080604083850312156114be57600080fd5b50508035926020909101359150565b6000602082840312156114df57600080fd5b61047882611443565b600080604083850312156114fb57600080fd5b61150483611443565b946020939093013593505050565b60006020828403121561152457600080fd5b815160ff8116811461047857600080fd5b634e487b7160e01b600052601160045260246000fd5b600181815b8085111561158657816000190482111561156c5761156c611535565b8085161561157957918102915b93841c9390800290611550565b509250929050565b60008261159d575060016104a9565b816115aa575060006104a9565b81600181146115c057600281146115ca576115e6565b60019150506104a9565b60ff8411156115db576115db611535565b50506001821b6104a9565b5060208310610133831016604e8410600b8410161715611609575081810a6104a9565b611613838361154b565b806000190482111561162757611627611535565b029392505050565b600061047860ff84168361158e565b600081600019048311821515161561165857611658611535565b500290565b60008261167a57634e487b7160e01b600052601260045260246000fd5b500490565b60008282101561169157611691611535565b500390565b600082198211156116a9576116a9611535565b500190565b6000602082840312156116c057600080fd5b8151801515811461047857600080fd5b6000602082840312156116e257600080fd5b505191905056fea26469706673582212204d85633baa484cb7a3531bb70c552dac8b0e0b068fa8e109eef5f4fbbd3c86f064736f6c634300080d0033";

type CDPPoolConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: CDPPoolConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class CDPPool__factory extends ContractFactory {
  constructor(...args: CDPPoolConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
  }

  override deploy(
    _moduleManager: PromiseOrValue<string>,
    _priceOracle: PromiseOrValue<string>,
    _collateral: PromiseOrValue<string>,
    _minCR: PromiseOrValue<BigNumberish>,
    _liquidationCR: PromiseOrValue<BigNumberish>,
    _minDebt: PromiseOrValue<BigNumberish>,
    _protocolFee: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<CDPPool> {
    return super.deploy(
      _moduleManager,
      _priceOracle,
      _collateral,
      _minCR,
      _liquidationCR,
      _minDebt,
      _protocolFee,
      overrides || {}
    ) as Promise<CDPPool>;
  }
  override getDeployTransaction(
    _moduleManager: PromiseOrValue<string>,
    _priceOracle: PromiseOrValue<string>,
    _collateral: PromiseOrValue<string>,
    _minCR: PromiseOrValue<BigNumberish>,
    _liquidationCR: PromiseOrValue<BigNumberish>,
    _minDebt: PromiseOrValue<BigNumberish>,
    _protocolFee: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(
      _moduleManager,
      _priceOracle,
      _collateral,
      _minCR,
      _liquidationCR,
      _minDebt,
      _protocolFee,
      overrides || {}
    );
  }
  override attach(address: string): CDPPool {
    return super.attach(address) as CDPPool;
  }
  override connect(signer: Signer): CDPPool__factory {
    return super.connect(signer) as CDPPool__factory;
  }

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): CDPPoolInterface {
    return new utils.Interface(_abi) as CDPPoolInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): CDPPool {
    return new Contract(address, _abi, signerOrProvider) as CDPPool;
  }
}
