import yargs, { Argv } from "yargs";
import { logger } from "../logging";
import { loadEnv } from "../env";
import { execute, generateForgeCommand, generateSignature } from "./deploy"
import { verifyModule, verifyNetwork } from "../helpers";
import { CLIArgs, CLIEnvironment, CommandParams } from "../types";
import { ethers } from "ethers";

const buildHelp = () => {
  let help = "$0 protocol deploy [target]\n Photon protocol deployment";
  return help;
};

export const addModule = async (cli: CLIEnvironment, cliArgs: CLIArgs): Promise<void> => {
    const { c: networkId, moduleId } = cliArgs;
    if ( !verifyModule(networkId, moduleId)) return;
    let sig: string = await generateSignature([{
        type: "string",
        value: networkId.toString()
    }, {
        type: "address",
        value: moduleId
    }]);

    let commandParams: CommandParams = {
        contractName: "UpdateAddModule",
        forkUrl: cli.providerUrl,
        privateKey: cli.argv.privateKey,
        sig
    }
    let forgeCommand = generateForgeCommand(commandParams);
    await execute(forgeCommand);
    
    logger.info(`Successfully added module ${moduleId}`);
};

export const updateCeiling = async (cli: CLIEnvironment, cliArgs: CLIArgs): Promise<void> => {
    let { c: networkId, moduleId, ceiling } = cliArgs;
    
    if (!verifyModule(networkId, moduleId)) return;
    let ceilingD18 = ethers.utils.parseUnits(ceiling, 18);
    let sig: string = await generateSignature([{
        type: "string",
        value: networkId.toString()
    }, {
        type: "address",
        value: moduleId
    }, {
      type: "uint256",
      value: ceilingD18
    }]);

    let commandParams: CommandParams = {
      contractName: "UpdateModulePHOCeiling",
      forkUrl: cli.providerUrl,
      privateKey: cli.argv.privateKey,
      sig
  }
  let forgeCommand = generateForgeCommand(commandParams);
  await execute(forgeCommand);

  logger.info(`Successfully updated PHO ceiling for module ${moduleId}`);

}

export const executeCeilingUpdate = async (cli: CLIEnvironment, cliArgs: CLIArgs): Promise<void> => {
  let { c: networkId, moduleId } = cliArgs;

  if (!verifyModule(networkId, moduleId)) return;

  let sig: string = await generateSignature([{
      type: "string",
      value: networkId.toString()
  }, {
      type: "address",
      value: moduleId
  }]);

  let commandParams: CommandParams = {
    contractName: "UpdateExecuteCeilingUpdate",
    forkUrl: cli.providerUrl,
    privateKey: cli.argv.privateKey,
    sig
}
let forgeCommand = generateForgeCommand(commandParams);
await execute(forgeCommand);

logger.info(`Successfully updated ceiling for module ${moduleId}`);

}


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
}

export const executePHOUpdateCommand = {
  command: "execute-ceiling [moduleId]",
  describe: "Executes ceiling update for a module",
  builder: (yargs: Argv): yargs.Argv => {
    return yargs.usage(buildHelp());
  },
  handler: async (argv: CLIArgs): Promise<void> => {
    return executeCeilingUpdate(await loadEnv(argv), argv);
  },
}
