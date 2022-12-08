import yargs, { Argv } from "yargs";
import { listCommand } from "./list";
import { getCommand } from "./get";
import { deployCommand } from "./deploy";
import { addModuleCommand, executePHOUpdateCommand, listModuleDataCommand, updateModuleCeilingCommand } from "./module";
import { fastForwardCommand } from "./evm";

// TODO: print help with fn signature
// TODO: add gas price

export const protocolCommand = {
  command: "protocol",
  describe: "Photon protocol configuration",
  builder: (yargs: Argv): yargs.Argv => {
    return yargs.command(getCommand).command(listCommand).command(deployCommand);
  },
  handler: (): void => {
    yargs.showHelp();
  },
};

export const evmCommand = {
  command: "evm",
  describe: "EVM manipulation",
  builder: (yargs: Argv): yargs.Argv => {
    return yargs.command(fastForwardCommand);
  },
  handler: (): void => {
    yargs.showHelp();
  },
};

export const moduleCommand = {
  command: "module",
  describe: "module manipulation",
  builder: (yargs: Argv): yargs.Argv => {
    return yargs
      .command(addModuleCommand)
      .command(updateModuleCeilingCommand)
      .command(executePHOUpdateCommand)
      .command(listModuleDataCommand)
  },
  handler: (): void => {
    yargs.showHelp();
  },
};
