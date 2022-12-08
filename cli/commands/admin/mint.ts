import { ethers, logger } from "ethers";
import yargs, { Argv } from "yargs"
import { loadEnv } from "../../env";
import { toPHO } from "../../network";
import { CLIArgs, CLIEnvironment } from "../../types";
import { execute } from "../deploy";
import { fastForward } from "../evm/fastForward";


const buildHelp = () => {
    let help = "Mint PHO -> admin mint [to] [amount]";
    return help;
  };

export const mintPHO = async (cli: CLIEnvironment, cliArgs: CLIArgs): Promise<void> => {
    let { to, amount } = cliArgs;
    const { ModuleManager, PHO } = cli.contracts;
    const adminAddress = cli.wallet.address;

    const moduleData = await ModuleManager.modules(adminAddress);
    if(!moduleData.status) {
        await ModuleManager.addModule(adminAddress);
        await ModuleManager.setPHOCeilingForModule(adminAddress, ethers.constants.MaxUint256);
        cli.argv.seconds = 1814400;
        await fastForward(cli, cliArgs);
        await ModuleManager.executeCeilingUpdate(adminAddress);
    }

    amount = toPHO(amount);
    await ModuleManager.mintPHO(to, amount);
    logger.info(`Successfully minted $PHO to ${to}`);
    logger.info(`Current ${to} balance = ${await PHO.balanceOf(to)}`);
} 

export const mintCommand = {
    command: "mint [to] [amount]",
    describe: "Mint a certain amount to an address",
    builder: (yargs: Argv): yargs.Argv => {
      return yargs.usage(buildHelp());
    },
    handler: async (argv: CLIArgs): Promise<void> => {
      return mintPHO(await loadEnv(argv), argv);
    },
  };