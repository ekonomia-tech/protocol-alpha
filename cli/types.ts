import { PHO } from "../build/types/PHO";
import { TON } from "../build/types/TON";
import { ModuleManager } from "../build/types/ModuleManager";
import { Kernel } from "../build/types/Kernel";
import { ChainlinkPriceFeed } from "../build/types/ChainlinkPriceFeed";
import { ICurvePool } from "../build/types/ICurvePool";
import { BigNumber, Wallet } from "ethers";
import { Argv } from "yargs";

export interface SignatureParam {
  type: string;
  value: string | number;
}

export interface DeployParams {
  name: string;
  description: string;
  deploy: boolean;
  contractName: string;
  sigParams: SignatureParam[];
  isCore: boolean;
  contractLabel: string | null;
}

export interface AddressLogData {
  name: string;
  sig: string;
}

export type MasterAddresses = Record<string, NetworkContracts>;

export interface NetworkContracts {
  core: Record<string, string>;
  modules: Record<string, string>;
}

export type Networks = Record<string, string>;

export interface CommandParams {
  contractName: string;
  forkUrl: string;
  privateKey: string;
  sig: string;
  networkId: number;
}

export interface AddressParams {
  contractName: string;
  truncSig: string;
  networkId: number;
  isCore: boolean;
  contractLabel: string | null;
}

export interface PhotonContracts {
  PHO: PHO;
  TON: TON;
  Kernel: Kernel;
  ModuleManager: ModuleManager;
  ChainlinkPriceFeed: ChainlinkPriceFeed;
  CurvePool: ICurvePool;
}

export type CLIArgs = Record<string, any> & Argv["argv"];

export interface CLIEnvironment {
  balance: BigNumber;
  chainId: number;
  nonce: number;
  walletAddress: string;
  wallet: Wallet;
  contracts: PhotonContracts;
  argv: CLIArgs;
  providerUrl: string;
}

export interface ProtocolFunction {
  contract: string;
  name: string;
}
