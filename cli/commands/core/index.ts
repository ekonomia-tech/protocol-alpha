import yargs, { Argv } from "yargs";
import { readCommand } from "./read";

export const coreCommand = {
    command: "core",
    describe: "Photon protocol configuration",
    builder: (yargs: Argv): yargs.Argv => {
      return yargs
      .command(readCommand)
    },
    handler: (): void => {
      yargs.showHelp();
    },
};

  