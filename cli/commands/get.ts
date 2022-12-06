import yargs, { Argv } from "yargs";

import { logger } from "../logging";
import { getContract } from "../contracts";
import { loadEnv, CLIArgs, CLIEnvironment } from "../env";
import { ContractFunction } from "ethers";

import { ProtocolFunction } from "./index";

// TODO - add in module-specific getters, but maybe in another object
export const getters = {
  "pho-supply": { contract: "PHO", name: "totalSupply" },
  "pho-owner": { contract: "PHO", name: "owner" },
  "pho-kernel": { contract: "PHO", name: "kernel" },
  "ton-supply": { contract: "TON", name: "totalSupply" },
  "kernel-ton-governance": { contract: "Kernel", name: "pho" },
  // "mm-pho-governance": { contract: "ModuleManager", name: "PHOGovernance" },
  // "mm-ton-governance": { contract: "ModuleManager", name: "TONGovernance" },
  "mm-pause-guardian": { contract: "ModuleManager", name: "pauseGuardian" },
  "mm-module-delay": { contract: "ModuleManager", name: "moduleDelay" },
  // "mm-module-module": { contract: "ModuleManager", name: "modules" },
};

const buildHelp = () => {
  let help = "$0 protocol get <fn> [params]\n Photon protocol configuration\n\nCommands:\n\n";
  for (const entry of Object.keys(getters)) {
    help += "  $0 protocol get " + entry + " [params]\n";
  }
  return help;
};

export const getProtocolParam = async (cli: CLIEnvironment, cliArgs: CLIArgs): Promise<void> => {
  logger.info(`Getting ${cliArgs.fn}...`);
  const fn: ProtocolFunction = getters[cliArgs.fn];
  if (!fn) {
    logger.error(`Command ${cliArgs.fn} does not exist`);
    return;
  }

  // Parse params
  const params = cliArgs.params ? cliArgs.params.toString().split(",") : [];

  // Send tx
  const contractFn: ContractFunction = cli.contracts[fn.contract].functions[fn.name];

  const [value] = await contractFn(...params);
  logger.info(`${fn.name} = ${value}`);
};

export const getCommand = {
  command: "get <fn> [params]",
  describe: "Get network parameter",
  builder: (yargs: Argv): yargs.Argv => {
    return yargs.usage(buildHelp());
  },
  handler: async (argv: CLIArgs): Promise<void> => {
    return getProtocolParam(await loadEnv(argv), argv);
  },
};
