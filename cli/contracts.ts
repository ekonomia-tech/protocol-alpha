import { Contract, providers, Signer } from "ethers";
import { loadABI } from "./abis";
import { PHO } from "../build/types/PHO";
import { TON } from "../build/types/TON";
import { ModuleManager } from "../build/types/ModuleManager";
import { Kernel } from "../build/types/Kernel";
import { ChainlinkPriceFeed } from "../build/types/ChainlinkPriceFeed";
import { ICurvePool } from "../build/types/ICurvePool";
import { PhotonContracts } from "./types";

/// @dev get a single contract.
/// @returns Generic Contract object
export const getContract = (
  name: string,
  address: string,
  signerOrProvider?: Signer | providers.Provider,
): Contract => {
  return new Contract(address, loadABI(name), signerOrProvider);
};

/// @dev Loads all the core photon contracts
/// TODO - make it more robust, instead of hardcoding types and maybe doing the abis differently
export const getContracts = (
  addresses: any, // TODO make more robust
  signerOrProvider?: Signer | providers.Provider,
): PhotonContracts => {
  const pho: PHO = new Contract(addresses.PHO, loadABI("PHO"), signerOrProvider) as PHO;
  const ton: TON = new Contract(addresses.TON, loadABI("TON"), signerOrProvider) as TON;
  const kernel: Kernel = new Contract(
    addresses.Kernel,
    loadABI("Kernel"),
    signerOrProvider,
  ) as Kernel;
  const moduleManager: ModuleManager = new Contract(
    addresses.ModuleManager,
    loadABI("ModuleManager"),
    signerOrProvider,
  ) as ModuleManager;
  const chainlinkPriceFeed: ChainlinkPriceFeed = new Contract(
    addresses.ChainlinkPriceFeed,
    loadABI("ChainlinkPriceFeed"),
    signerOrProvider,
  ) as ChainlinkPriceFeed;
  const curvePool: ICurvePool = addresses.curvePool
    ? (new Contract(addresses.CurvePool, loadABI("CurvePool"), signerOrProvider) as ICurvePool)
    : ({} as ICurvePool);
  const contracts: PhotonContracts = {
    PHO: pho,
    TON: ton,
    Kernel: kernel,
    ModuleManager: moduleManager,
    ChainlinkPriceFeed: chainlinkPriceFeed,
    CurvePool: curvePool,
  };
  return contracts;
};
