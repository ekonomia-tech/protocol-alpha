import yargs, { Argv } from "yargs";
import { logger } from "../logging";
import { CLIArgs, CLIEnvironment, loadEnv } from "../env";
import { execute, generateForgeCommand, generateSignature, getNetworkRPC } from "../../deploy/helpers";
import { deployContracts } from "../../deploy/deploy";
import { getModuleData, getModuleName, verifyModule, verifyNetwork } from "../helpers";
import { CommandParams } from "../../deploy/types";
import { BigNumber, ethers } from "ethers";
require('dotenv').config()

const buildHelp = () => {
  let help = "$0 protocol deploy [target]\n Photon protocol deployment";
  return help;
};

export const addModule = async (cli: CLIEnvironment, cliArgs: CLIArgs): Promise<void> => {
    const { target, moduleId } = cliArgs;
    if (!verifyNetwork(target) || !verifyModule(target, moduleId)) return;
    let sig: string = await generateSignature([{
        type: "string",
        value: target
    }, {
        type: "address",
        value: moduleId
    }]);

    let commandParams: CommandParams = {
        contractName: "UpdateAddModule",
        forkUrl: getNetworkRPC(target),
        privateKey: cli.argv.privateKey,
        sig
    }
    let forgeCommand = generateForgeCommand(commandParams);
    await execute(forgeCommand);
    
    logger.info(`Successfully added module ${moduleId}`);
};

export const updateCeiling = async (cli: CLIEnvironment, cliArgs: CLIArgs): Promise<void> => {
    let { target, moduleId, ceiling } = cliArgs;
    
    if (!verifyNetwork(target) || !verifyModule(target, moduleId)) return;
    let ceiling_d18 = ethers.utils.parseUnits(ceiling, 18);
    let sig: string = await generateSignature([{
        type: "string",
        value: target
    }, {
        type: "address",
        value: moduleId
    }, {
      type: "uint256",
      value: ceiling_d18
    }]);

    let commandParams: CommandParams = {
      contractName: "UpdateModulePHOCeiling",
      forkUrl: getNetworkRPC(target),
      privateKey: cli.argv.privateKey,
      sig
  }
  let forgeCommand = generateForgeCommand(commandParams);
  await execute(forgeCommand);

  logger.info(`Successfully updated PHO ceiling for module ${moduleId}`);

}

export const executeCeilingUpdate = async (cli: CLIEnvironment, cliArgs: CLIArgs): Promise<void> => {
  let { target, moduleId } = cliArgs;

  if (!verifyNetwork(target) || !verifyModule(target, moduleId)) return;

  let sig: string = await generateSignature([{
      type: "string",
      value: target
  }, {
      type: "address",
      value: moduleId
  }]);

  let commandParams: CommandParams = {
    contractName: "UpdateExecuteCeilingUpdate",
    forkUrl: getNetworkRPC(target),
    privateKey: cli.argv.privateKey,
    sig
}
let forgeCommand = generateForgeCommand(commandParams);
await execute(forgeCommand);

logger.info(`Successfully updated ceiling for module ${moduleId}`);

}


export const addModuleCommand = {
  command: "add [target] [moduleId]",
  describe: "Adds a module to module manager",
  builder: (yargs: Argv): yargs.Argv => {
    return yargs.usage(buildHelp());
  },
  handler: async (argv: CLIArgs): Promise<void> => {
    return addModule(await loadEnv(argv), argv);
  },
};

export const updateModuleCeilingCommand = {
  command: "update-ceiling [target] [moduleId] [ceiling]",
  describe: "Updates PHO ceiling for a given module",
  builder: (yargs: Argv): yargs.Argv => {
    return yargs.usage(buildHelp());
  },
  handler: async (argv: CLIArgs): Promise<void> => {
    return updateCeiling(await loadEnv(argv), argv);
  },
}

export const executePHOUpdateCommand = {
  command: "execute-ceiling [target] [moduleId]",
  describe: "Executes ceiling update for a module",
  builder: (yargs: Argv): yargs.Argv => {
    return yargs.usage(buildHelp());
  },
  handler: async (argv: CLIArgs): Promise<void> => {
    return executeCeilingUpdate(await loadEnv(argv), argv);
  },
}
