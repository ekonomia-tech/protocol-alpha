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
  Overrides,
  PopulatedTransaction,
  Signer,
  utils,
} from "ethers";
import type {
  FunctionFragment,
  Result,
  EventFragment,
} from "@ethersproject/abi";
import type { Listener, Provider } from "@ethersproject/providers";
import type {
  TypedEventFilter,
  TypedEvent,
  TypedListener,
  OnEvent,
  PromiseOrValue,
} from "./common";

export interface IKernelInterface extends utils.Interface {
  functions: {
    "burnPHO(address,uint256)": FunctionFragment;
    "mintPHO(address,uint256)": FunctionFragment;
    "updateModuleManager(address)": FunctionFragment;
    "updateModuleManagerDelay(uint256)": FunctionFragment;
  };

  getFunction(
    nameOrSignatureOrTopic:
      | "burnPHO"
      | "mintPHO"
      | "updateModuleManager"
      | "updateModuleManagerDelay"
  ): FunctionFragment;

  encodeFunctionData(
    functionFragment: "burnPHO",
    values: [PromiseOrValue<string>, PromiseOrValue<BigNumberish>]
  ): string;
  encodeFunctionData(
    functionFragment: "mintPHO",
    values: [PromiseOrValue<string>, PromiseOrValue<BigNumberish>]
  ): string;
  encodeFunctionData(
    functionFragment: "updateModuleManager",
    values: [PromiseOrValue<string>]
  ): string;
  encodeFunctionData(
    functionFragment: "updateModuleManagerDelay",
    values: [PromiseOrValue<BigNumberish>]
  ): string;

  decodeFunctionResult(functionFragment: "burnPHO", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "mintPHO", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "updateModuleManager",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "updateModuleManagerDelay",
    data: BytesLike
  ): Result;

  events: {
    "ModuleManagerDelayUpdated(uint256)": EventFragment;
    "ModuleManagerUpdated(address)": EventFragment;
  };

  getEvent(nameOrSignatureOrTopic: "ModuleManagerDelayUpdated"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "ModuleManagerUpdated"): EventFragment;
}

export interface ModuleManagerDelayUpdatedEventObject {
  newDelay: BigNumber;
}
export type ModuleManagerDelayUpdatedEvent = TypedEvent<
  [BigNumber],
  ModuleManagerDelayUpdatedEventObject
>;

export type ModuleManagerDelayUpdatedEventFilter =
  TypedEventFilter<ModuleManagerDelayUpdatedEvent>;

export interface ModuleManagerUpdatedEventObject {
  newModuleManager: string;
}
export type ModuleManagerUpdatedEvent = TypedEvent<
  [string],
  ModuleManagerUpdatedEventObject
>;

export type ModuleManagerUpdatedEventFilter =
  TypedEventFilter<ModuleManagerUpdatedEvent>;

export interface IKernel extends BaseContract {
  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  interface: IKernelInterface;

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
    burnPHO(
      from: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    mintPHO(
      to: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    updateModuleManager(
      newModuleManager: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    updateModuleManagerDelay(
      newDelay: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;
  };

  burnPHO(
    from: PromiseOrValue<string>,
    amount: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  mintPHO(
    to: PromiseOrValue<string>,
    amount: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  updateModuleManager(
    newModuleManager: PromiseOrValue<string>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  updateModuleManagerDelay(
    newDelay: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  callStatic: {
    burnPHO(
      from: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<void>;

    mintPHO(
      to: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<void>;

    updateModuleManager(
      newModuleManager: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<void>;

    updateModuleManagerDelay(
      newDelay: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<void>;
  };

  filters: {
    "ModuleManagerDelayUpdated(uint256)"(
      newDelay?: null
    ): ModuleManagerDelayUpdatedEventFilter;
    ModuleManagerDelayUpdated(
      newDelay?: null
    ): ModuleManagerDelayUpdatedEventFilter;

    "ModuleManagerUpdated(address)"(
      newModuleManager?: PromiseOrValue<string> | null
    ): ModuleManagerUpdatedEventFilter;
    ModuleManagerUpdated(
      newModuleManager?: PromiseOrValue<string> | null
    ): ModuleManagerUpdatedEventFilter;
  };

  estimateGas: {
    burnPHO(
      from: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    mintPHO(
      to: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    updateModuleManager(
      newModuleManager: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    updateModuleManagerDelay(
      newDelay: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;
  };

  populateTransaction: {
    burnPHO(
      from: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    mintPHO(
      to: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    updateModuleManager(
      newModuleManager: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    updateModuleManagerDelay(
      newDelay: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;
  };
}