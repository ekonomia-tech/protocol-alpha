import yargs, { Argv } from "yargs";
import { logger } from "../../../logging";
import { loadEnv } from "../../../env";
import { getNetworkContractAddresses } from "../../../helpers";
import { CLIArgs, CLIEnvironment } from "../../../types";
import { ethers } from "ethers";
import Table from "cli-table3";


const listModuleData = async (cli: CLIEnvironment, cliArgs: CLIArgs): Promise<void> => {
    const { ModuleManager } = cli.contracts;
    const { c: networkId } = cli.argv;
    const { modules } = getNetworkContractAddresses(networkId);

    for (const [ name, address ] of Object.entries(modules)) {
      const moduleData = await ModuleManager.modules(address);
      if (moduleData.status == 0) return;
      const table = new Table({
        head: [name, "Result"],
        colWidths: [30, 50],
      });
      
      table.push(["Address", address]);
      Object.entries(moduleData).slice(-6).forEach(([ name, value ]) => {
        let stringValue = value.toString();
        if (["phoCeiling", "phoMinted", "upcomingCeiling"].includes(name)) {
          stringValue = ethers.utils.formatEther(value);
        }
          table.push([name, stringValue]);
      });

      logger.info(table.toString());
     
    }
}

export const listModuleDataCommand = {
    command: "list",
    describe: "lists modules data",
    handler: async (argv: CLIArgs): Promise<void> => {
      return listModuleData(await loadEnv(argv), argv);
    },
};


  
