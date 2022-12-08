import yargs, { Argv } from "yargs";
import { logger } from "../logging";
import { loadEnv } from "../env";
import { execute, generateForgeCommand, generateSignature } from "./deploy";
import { getNetworkContractAddresses, verifyModule } from "../helpers";
import { CLIArgs, CLIEnvironment, CommandParams } from "../types";
import { ethers } from "ethers";
import { IModuleManager } from "../../build/types/IModuleManager"; 
import Table from "cli-table3";


const listModuleData = async (cli: CLIEnvironment, cliArgs: CLIArgs): Promise<void> => {
    const { ModuleManager } = cli.contracts;
    const { c: networkId } = cli.argv;
    const { modules } = getNetworkContractAddresses(networkId);

    for (const [ name, address ] of Object.entries(modules)) {
      const moduleData = await ModuleManager.modules(address);
      if (moduleData.status == 0) return;
      const table = new Table({
        head: [name, "Result"],
        colWidths: [30, 50],
      });
      
      table.push(["Address", address]);
      Object.entries(moduleData).slice(-6).forEach(([ name, value ]) => {
        let stringValue = value.toString();
        if (["phoCeiling", "phoMinted", "upcomingCeiling"].includes(name)) {
          stringValue = ethers.utils.formatEther(value);
        }
          table.push([name, stringValue]);
      });

      logger.info(table.toString());
     
    }
    


}

const buildHelp = () => {
  let help = "$0 protocol deploy [target]\n Photon protocol deployment";
  return help;
};

export const addModule = async (cli: CLIEnvironment, cliArgs: CLIArgs): Promise<void> => {
  const { c: networkId, moduleId } = cliArgs;
  if (!verifyModule(networkId, moduleId)) return;
  let sig: string = await generateSignature([
    {
      type: "string",
      value: networkId.toString(),
    },
    {
      type: "address",
      value: moduleId,
    },
  ]);

  let commandParams: CommandParams = {
    contractName: "UpdateAddModule",
    forkUrl: cli.providerUrl,
    privateKey: cli.wallet.privateKey,
    sig,
    networkId,
  };
  let forgeCommand = generateForgeCommand(commandParams);
  await execute(forgeCommand);

  logger.info(`Successfully added module ${moduleId}`);
};

export const updateCeiling = async (cli: CLIEnvironment, cliArgs: CLIArgs): Promise<void> => {
  let { c: networkId, moduleId, ceiling } = cliArgs;

  if (!verifyModule(networkId, moduleId)) return;
  let ceilingD18 = ethers.utils.parseUnits(ceiling, 18);
  let sig: string = await generateSignature([
    {
      type: "string",
      value: networkId.toString(),
    },
    {
      type: "address",
      value: moduleId,
    },
    {
      type: "uint256",
      value: ceilingD18,
    },
  ]);

  let commandParams: CommandParams = {
    contractName: "UpdateModulePHOCeiling",
    forkUrl: cli.providerUrl,
    privateKey: cli.wallet.privateKey,
    sig,
    networkId,
  };
  let forgeCommand = generateForgeCommand(commandParams);
  await execute(forgeCommand);

  logger.info(`Successfully updated PHO ceiling for module ${moduleId}`);
};

export const executeCeilingUpdate = async (
  cli: CLIEnvironment,
  cliArgs: CLIArgs,
): Promise<void> => {
  let { c: networkId, moduleId } = cliArgs;

  if (!verifyModule(networkId, moduleId)) return;

  let sig: string = await generateSignature([
    {
      type: "string",
      value: networkId.toString(),
    },
    {
      type: "address",
      value: moduleId,
    },
  ]);

  let commandParams: CommandParams = {
    contractName: "UpdateExecuteCeilingUpdate",
    forkUrl: cli.providerUrl,
    privateKey: cli.wallet.privateKey,
    sig,
    networkId,
  };
  let forgeCommand = generateForgeCommand(commandParams);
  await execute(forgeCommand);

  logger.info(`Successfully updated ceiling for module ${moduleId}`);
};

export const listModuleDataCommand = {
  command: "list",
  describe: "lists modules data",
  builder: (yargs: Argv): yargs.Argv => {
    return yargs.usage(buildHelp());
  },
  handler: async (argv: CLIArgs): Promise<void> => {
    return listModuleData(await loadEnv(argv), argv);
  },
};

export const addModuleCommand = {
  command: "add [moduleId]",
  describe: "Adds a module to module manager",
  builder: (yargs: Argv): yargs.Argv => {
    return yargs.usage(buildHelp());
  },
  handler: async (argv: CLIArgs): Promise<void> => {
    return addModule(await loadEnv(argv), argv);
  },
};

export const updateModuleCeilingCommand = {
  command: "update-ceiling [moduleId] [ceiling]",
  describe: "Updates PHO ceiling for a given module",
  builder: (yargs: Argv): yargs.Argv => {
    return yargs.usage(buildHelp());
  },
  handler: async (argv: CLIArgs): Promise<void> => {
    return updateCeiling(await loadEnv(argv), argv);
  },
};

export const executePHOUpdateCommand = {
  command: "execute-ceiling [moduleId]",
  describe: "Executes ceiling update for a module",
  builder: (yargs: Argv): yargs.Argv => {
    return yargs.usage(buildHelp());
  },
  handler: async (argv: CLIArgs): Promise<void> => {
    return executeCeilingUpdate(await loadEnv(argv), argv);
  },
};
