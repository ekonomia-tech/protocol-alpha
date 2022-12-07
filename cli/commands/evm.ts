import yargs, { Argv } from "yargs";
import { loadEnv } from "../env";
import { CLIArgs, CLIEnvironment } from "../types";
import { execute } from "./deploy";

const buildHelp = () => {
  let help = "$0 protocol deploy [target]\n Photon protocol deployment";
  return help;
};

export const fastForward = async (cli: CLIEnvironment, cliArgs: CLIArgs): Promise<void> => {
  const { seconds, hours, days } = cli.argv;  
    let toJump = seconds;  
    if (hours) {
      toJump += hours * 3600;
    }
    if (days) {
      toJump += days * 86400
    }
    await execute(`curl -H "Content-Type: application/json" -X POST --data '{"jsonrpc":"2.0","method":"evm_increaseTime","params":[${toJump}],"id":67}' ${cli.providerUrl}`)
    await execute(`curl -H "Content-Type: application/json" -X POST --data '{"jsonrpc":"2.0","method":"evm_mine","params":[],"id":67}' ${cli.providerUrl}`)
};

export const fastForwardCommand = {
  command: "fast-forward [seconds] [hours] [days]",
  describe: "deploy contracts from deployParams.json",
  builder: (yargs: Argv): yargs.Argv => {
    return yargs.usage(buildHelp());
  },
  handler: async (argv: CLIArgs): Promise<void> => {
    return fastForward(await loadEnv(argv), argv);
  },
};
