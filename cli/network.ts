import { providers, utils, BigNumber } from "ethers";

const { keccak256, randomBytes, parseUnits, hexlify } = utils;

// Bytes
export const randomHexBytes = (n = 32): string => hexlify(randomBytes(n));
export const hashHexString = (input: string): string => keccak256(`0x${input.replace(/^0x/, "")}`);

// Numbers
export const toBN = (value: string | number | BigNumber): BigNumber => BigNumber.from(value);
export const toPHO = (value: string | number): BigNumber => {
  return parseUnits(typeof value === "number" ? value.toString() : value, "18");
};
export const toTON = toPHO; // both 18 decimals

// Providers
export const getProvider = (providerUrl: string, network?: number): providers.JsonRpcProvider =>
  new providers.JsonRpcProvider(providerUrl, network);
