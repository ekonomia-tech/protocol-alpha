import yargs, { Argv } from "yargs";
import { getCommand } from "./get";
import { listCommand } from "./list";

export const readCommand = {
    command: "read",
    describe: "readOnly",
    builder: (yargs: Argv): yargs.Argv => {
      return yargs
      .command(getCommand)
      .command(listCommand)
    },
    handler: (): void => {
      yargs.showHelp();
    },
};
  