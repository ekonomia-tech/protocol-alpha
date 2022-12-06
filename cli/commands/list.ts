import Table from "cli-table3";

import { loadEnv, CLIArgs, CLIEnvironment } from "../env";
import { PhotonContracts } from "../contracts";
import { logger } from "../logging";
import { ContractFunction } from "ethers";
import addresses from "../../addresses.json";

import { getters } from "./get";

const coreContracts = ["PHO", "TON", "Kernel", "ModuleManager", "ChainlinkPriceFeed", "CurvePool"];

const forkedMainnet = addresses.render.core; // TODO make generalized

export const listProtocolParams = async (cli: CLIEnvironment): Promise<void> => {
  logger.info(`>>> Protocol Configuration <<<\n`);

  for (const name of coreContracts) {
    const table = new Table({
      head: [name, "Result"],
      colWidths: [30, 50],
    });

    if (!(name in cli.contracts)) {
      continue;
    }
    table.push(["Address", forkedMainnet[name]]);

    const req = [];
    for (const fn of Object.values(getters)) {
      if (fn.contract != name) continue;
      const contract = cli.contracts[fn.contract];
      if (contract.interface.getFunction(fn.name).inputs.length == 0) {
        const contractFn: ContractFunction = contract.functions[fn.name];
        req.push(
          contractFn().then((values) => {
            let [value] = values;
            if (typeof value === "object") {
              value = value.toString();
            }
            table.push([fn.name, value]);
          }),
        );
      }
    }
    await Promise.all(req);
    logger.info(table.toString());
  }

  // Verify controllers
  // logger.info(`\n>>> Contracts Controller <<<\n`)

  // const controller = cli.contracts['Controller']
  // for (const contractName of contractNames) {
  //   if (contractName === 'Controller' || !(contractName in cli.contracts)) continue

  //   const contract = cli.contracts[contractName]
  //   const contractFn = contract.functions['controller']

  //   if (contractFn) {
  //     const addr = await contractFn().then((values) => values[0])
  //     if (addr === controller.address) {
  //       logger.info(contractName)
  //     } else {
  //       logger.error(`${contractName} : ${addr} should be ${controller.address}`)
  //     }
  //   } else {
  //     logger.info(contractName)
  //   }
  // }
};

export const listCommand = {
  command: "list",
  describe: "List protocol parameters",
  handler: async (argv: CLIArgs): Promise<void> => {
    return listProtocolParams(await loadEnv(argv));
  },
};
