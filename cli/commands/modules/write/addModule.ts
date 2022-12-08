import yargs, { Argv } from "yargs";
import { logger } from "../../../logging";
import { loadEnv } from "../../../env";
import { execute, generateForgeCommand, generateSignature } from "../../deploy";
import { verifyModule } from "../../../helpers";
import { CLIArgs, CLIEnvironment, CommandParams } from "../../../types";

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

