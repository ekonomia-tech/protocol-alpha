import yargs, { Argv } from "yargs";
import { mintCommand } from "./mint";

export const adminCommand = {
    command: "admin",
    describe: "Perform administrative actions on testnet",
    builder: (yargs: Argv): yargs.Argv => {
      return yargs
      .command(mintCommand)
    },
    handler: (): void => {
      yargs.showHelp();
    },
};