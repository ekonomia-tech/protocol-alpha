/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import type {
  BaseContract,
  BigNumber,
  BigNumberish,
  BytesLike,
  CallOverrides,
  ContractTransaction,
  PayableOverrides,
  PopulatedTransaction,
  Signer,
  utils,
} from "ethers";
import type { FunctionFragment, Result } from "@ethersproject/abi";
import type { Listener, Provider } from "@ethersproject/providers";
import type {
  TypedEventFilter,
  TypedEvent,
  TypedListener,
  OnEvent,
  PromiseOrValue,
} from "./common";

export interface WstETHCDPWrapperInterface extends utils.Interface {
  functions: {
    "STETH()": FunctionFragment;
    "WETH()": FunctionFragment;
    "WSTETH()": FunctionFragment;
    "addCollateral(uint256,address)": FunctionFragment;
    "open(uint256,uint256,address)": FunctionFragment;
    "pool()": FunctionFragment;
  };

  getFunction(
    nameOrSignatureOrTopic:
      | "STETH"
      | "WETH"
      | "WSTETH"
      | "addCollateral"
      | "open"
      | "pool"
  ): FunctionFragment;

  encodeFunctionData(functionFragment: "STETH", values?: undefined): string;
  encodeFunctionData(functionFragment: "WETH", values?: undefined): string;
  encodeFunctionData(functionFragment: "WSTETH", values?: undefined): string;
  encodeFunctionData(
    functionFragment: "addCollateral",
    values: [PromiseOrValue<BigNumberish>, PromiseOrValue<string>]
  ): string;
  encodeFunctionData(
    functionFragment: "open",
    values: [
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<string>
    ]
  ): string;
  encodeFunctionData(functionFragment: "pool", values?: undefined): string;

  decodeFunctionResult(functionFragment: "STETH", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "WETH", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "WSTETH", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "addCollateral",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "open", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "pool", data: BytesLike): Result;

  events: {};
}

export interface WstETHCDPWrapper extends BaseContract {
  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  interface: WstETHCDPWrapperInterface;

  queryFilter<TEvent extends TypedEvent>(
    event: TypedEventFilter<TEvent>,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TEvent>>;

  listeners<TEvent extends TypedEvent>(
    eventFilter?: TypedEventFilter<TEvent>
  ): Array<TypedListener<TEvent>>;
  listeners(eventName?: string): Array<Listener>;
  removeAllListeners<TEvent extends TypedEvent>(
    eventFilter: TypedEventFilter<TEvent>
  ): this;
  removeAllListeners(eventName?: string): this;
  off: OnEvent<this>;
  on: OnEvent<this>;
  once: OnEvent<this>;
  removeListener: OnEvent<this>;

  functions: {
    STETH(overrides?: CallOverrides): Promise<[string]>;

    WETH(overrides?: CallOverrides): Promise<[string]>;

    WSTETH(overrides?: CallOverrides): Promise<[string]>;

    addCollateral(
      _depositAmount: PromiseOrValue<BigNumberish>,
      _depositToken: PromiseOrValue<string>,
      overrides?: PayableOverrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    open(
      _depositAmount: PromiseOrValue<BigNumberish>,
      _debtAmount: PromiseOrValue<BigNumberish>,
      _depositToken: PromiseOrValue<string>,
      overrides?: PayableOverrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    pool(overrides?: CallOverrides): Promise<[string]>;
  };

  STETH(overrides?: CallOverrides): Promise<string>;

  WETH(overrides?: CallOverrides): Promise<string>;

  WSTETH(overrides?: CallOverrides): Promise<string>;

  addCollateral(
    _depositAmount: PromiseOrValue<BigNumberish>,
    _depositToken: PromiseOrValue<string>,
    overrides?: PayableOverrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  open(
    _depositAmount: PromiseOrValue<BigNumberish>,
    _debtAmount: PromiseOrValue<BigNumberish>,
    _depositToken: PromiseOrValue<string>,
    overrides?: PayableOverrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  pool(overrides?: CallOverrides): Promise<string>;

  callStatic: {
    STETH(overrides?: CallOverrides): Promise<string>;

    WETH(overrides?: CallOverrides): Promise<string>;

    WSTETH(overrides?: CallOverrides): Promise<string>;

    addCollateral(
      _depositAmount: PromiseOrValue<BigNumberish>,
      _depositToken: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<void>;

    open(
      _depositAmount: PromiseOrValue<BigNumberish>,
      _debtAmount: PromiseOrValue<BigNumberish>,
      _depositToken: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<void>;

    pool(overrides?: CallOverrides): Promise<string>;
  };

  filters: {};

  estimateGas: {
    STETH(overrides?: CallOverrides): Promise<BigNumber>;

    WETH(overrides?: CallOverrides): Promise<BigNumber>;

    WSTETH(overrides?: CallOverrides): Promise<BigNumber>;

    addCollateral(
      _depositAmount: PromiseOrValue<BigNumberish>,
      _depositToken: PromiseOrValue<string>,
      overrides?: PayableOverrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    open(
      _depositAmount: PromiseOrValue<BigNumberish>,
      _debtAmount: PromiseOrValue<BigNumberish>,
      _depositToken: PromiseOrValue<string>,
      overrides?: PayableOverrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    pool(overrides?: CallOverrides): Promise<BigNumber>;
  };

  populateTransaction: {
    STETH(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    WETH(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    WSTETH(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    addCollateral(
      _depositAmount: PromiseOrValue<BigNumberish>,
      _depositToken: PromiseOrValue<string>,
      overrides?: PayableOverrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    open(
      _depositAmount: PromiseOrValue<BigNumberish>,
      _debtAmount: PromiseOrValue<BigNumberish>,
      _depositToken: PromiseOrValue<string>,
      overrides?: PayableOverrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    pool(overrides?: CallOverrides): Promise<PopulatedTransaction>;
  };
}
