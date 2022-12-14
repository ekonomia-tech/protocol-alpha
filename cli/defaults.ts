import { Options } from "yargs";
import { Overrides } from "ethers";
import dotenv from "dotenv";
dotenv.config();

export const local = {
  mnemonic: "myth like bonus scare over problem client lizard pioneer submit female collect",
  chainId: 42069,
  accountNumber: "0",
};

// Used if having trouble pushing to goerli or mainnet
export const defaultOverrides: Overrides = {
  //  gasPrice: utils.parseUnits('25', 'gwei'), // auto
  //  gasLimit: 2000000, // auto
};

export const cliOpts = {
  chainId: {
    alias: "chainId",
    description: "The chain ID",
    type: "number",
    group: "Ethereum",
    default: local.chainId,
  },
  mnemonic: {
    alias: "mnemonic",
    description: "The mnemonic for an account which will pay for gas",
    type: "string",
    group: "Ethereum",
    default: local.mnemonic,
  },
  accountNumber: {
    alias: "account-number",
    description: "The account number of the mnemonic",
    type: "string",
    group: "Ethereum",
    default: local.accountNumber,
  },
} as Record<string, Options>;

export const rpcUrls = {
  1: process.env.MAINNET_RPC,
  11155111: process.env.SEPOLIA_RPC,
  42069: process.env.FORKED_MAINNET_URL,
};

export const coreContracts = [
  "PHO",
  "TON",
  "Kernel",
  "ModuleManager",
  "ChainlinkPriceFeed",
  "CurvePool",
];
