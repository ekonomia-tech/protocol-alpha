/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Contract, Signer, utils } from "ethers";
import type { Provider } from "@ethersproject/providers";
import type {
  IZeroCouponBondModule,
  IZeroCouponBondModuleInterface,
} from "../IZeroCouponBondModule";

const _abi = [
  {
    inputs: [],
    name: "CannotDepositAfterWindowEnd",
    type: "error",
  },
  {
    inputs: [],
    name: "CannotDepositBeforeWindowOpen",
    type: "error",
  },
  {
    inputs: [],
    name: "CannotRedeemBeforeWindowEnd",
    type: "error",
  },
  {
    inputs: [],
    name: "CannotRedeemMoreThanIssued",
    type: "error",
  },
  {
    inputs: [],
    name: "DepositWindowInvalid",
    type: "error",
  },
  {
    inputs: [],
    name: "OnlyModuleManager",
    type: "error",
  },
  {
    inputs: [],
    name: "OverEighteenDecimals",
    type: "error",
  },
  {
    inputs: [],
    name: "ZeroAddressDetected",
    type: "error",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "depositor",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "depositAmount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "mintAmount",
        type: "uint256",
      },
    ],
    name: "BondIssued",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "redeemer",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "redeemAmount",
        type: "uint256",
      },
    ],
    name: "BondRedeemed",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "interestRate",
        type: "uint256",
      },
    ],
    name: "InterestRateSet",
    type: "event",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "depositAmount",
        type: "uint256",
      },
    ],
    name: "depositBond",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "redeemBond",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "interestRate",
        type: "uint256",
      },
    ],
    name: "setInterestRate",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
];

export class IZeroCouponBondModule__factory {
  static readonly abi = _abi;
  static createInterface(): IZeroCouponBondModuleInterface {
    return new utils.Interface(_abi) as IZeroCouponBondModuleInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): IZeroCouponBondModule {
    return new Contract(
      address,
      _abi,
      signerOrProvider
    ) as IZeroCouponBondModule;
  }
}