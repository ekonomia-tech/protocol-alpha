import {
  providers,
  utils,
  Contract,
  ContractTransaction,
  Signer,
  BigNumber,
  PayableOverrides,
} from "ethers";
import { logger } from "./logging";
import { defaultOverrides } from "./defaults";

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
export const getProvider = (providerUrl: string): providers.JsonRpcProvider =>
  new providers.JsonRpcProvider(providerUrl);

export const waitTransaction = async (
  sender: Signer,
  tx: ContractTransaction,
): Promise<providers.TransactionReceipt> => {
  const receipt = await sender.provider.waitForTransaction(tx.hash);
  const networkName = (await sender.provider.getNetwork()).name;
  if (networkName === "goerli") {
    receipt.status // 1 = success, 0 = failure
      ? logger.info(`Transaction succeeded: 'https://${networkName}.etherscan.io/tx/${tx.hash}'`)
      : logger.warn(`Transaction failed: 'https://${networkName}.etherscan.io/tx/${tx.hash}'`);
  } else {
    receipt.status
      ? logger.info(`Transaction succeeded: ${tx.hash}`)
      : logger.warn(`Transaction failed: ${tx.hash}`);
  }
  return receipt;
};

export const sendTransaction = async (
  sender: Signer,
  contract: Contract,
  fn: string,
  // eslint-disable-next-line  @typescript-eslint/no-explicit-any
  params?: any[],
  overrides?: PayableOverrides,
): Promise<providers.TransactionReceipt> => {
  // Setup overrides
  if (overrides) {
    params.push(overrides);
  } else {
    params.push(defaultOverrides);
  }

  // Send transaction
  const tx: ContractTransaction = await contract.connect(sender).functions[fn](...params);
  if (tx === undefined) {
    logger.error(
      "It appears the function does not exist on this contract, or you have the wrong contract address",
    );
    throw new Error("Transaction error");
  }
  logger.info(
    `> Sent transaction ${fn}: [${params.slice(0, -1).toString()}] \n  contract: ${
      contract.address
    }\n  txHash: ${tx.hash}`,
  );

  // Wait for transaction to be mined
  return await waitTransaction(sender, tx);
};
