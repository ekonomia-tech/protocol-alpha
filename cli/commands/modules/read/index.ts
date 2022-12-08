import yargs, { Argv } from "yargs";
import { listModuleDataCommand } from "./list";

export const readCommand = {
    command: "read",
    describe: "readOnly",
    builder: (yargs: Argv): yargs.Argv => {
      return yargs
      .command(listModuleDataCommand)
    },
    handler: (): void => {
      yargs.showHelp();
    },
};