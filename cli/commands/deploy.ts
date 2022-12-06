import yargs, { Argv } from "yargs";
import { CLIArgs, CLIEnvironment, loadEnv } from "../env";
import { deployContracts } from "../../deploy/deploy";
import { verifyNetwork } from "../helpers";
require('dotenv').config()

const buildHelp = () => {
  let help = "$0 protocol deploy [target]\n Photon protocol deployment";
  return help;
};

export const deploy = async (cli: CLIEnvironment, cliArgs: CLIArgs): Promise<void> => {
    const { target } = cliArgs;
    if (!verifyNetwork(target)) return;
    await deployContracts(cliArgs.target, cli.argv.privateKey);
};

export const deployCommand = {
  command: "deploy [target]",
  describe: "deploy contracts from deployParams.json",
  builder: (yargs: Argv): yargs.Argv => {
    return yargs.usage(buildHelp());
  },
  handler: async (argv: CLIArgs): Promise<void> => {
    return deploy(await loadEnv(argv), argv);
  },
};
