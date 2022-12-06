import { ContractInterface } from "ethers";

import abiPHO from "../build/abis/PHO.sol/PHO.json";
import abiTON from "../build/abis/TON.sol/TON.json";
import abiMM from "../build/abis/ModuleManager.sol/ModuleManager.json";
import abiKernel from "../build/abis/Kernel.sol/Kernel.json";
import abiCLPF from "../build/abis/ChainlinkPriceFeed.sol/ChainlinkPriceFeed.json";
import abiCP from "../build/abis/ICurvePool.sol/ICurvePool.json";

export const loadABI = (name: string): ContractInterface => {
  switch (name) {
    case "PHO":
      return abiPHO.abi;
    case "TON":
      return abiTON.abi;
    case "Kernel":
      return abiKernel.abi;
    case "ModuleManager":
      return abiMM.abi;
    case "ChainlinkPriceFeed":
      return abiCLPF.abi;
    case "CurvePool":
      return abiCP.abi;
    default:
      return "ERROR_NO_ABI_FOUND"; // TODO - DK - Improve error
  }
};
