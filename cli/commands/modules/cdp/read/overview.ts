import Table from 'cli-table3'
import { BigNumber, logger } from 'ethers';
import { moduleDictionary } from '../../../../defaults';
import { loadEnv } from "../../../../env"
import { getModuleAddress } from "../../../../helpers"
import { CLIArgs, CLIEnvironment } from "../../../../types"
import { execute } from "../../../deploy";


const getOverview = async (cli: CLIEnvironment, cliArgs: CLIArgs) => {
    let moduleName = moduleDictionary.cdp[cliArgs.tokenType].default;
    let cdpAddress = getModuleAddress(cliArgs.c, "cdp", cliArgs.tokenType, "default");

    let moduleData = await cli.contracts.ModuleManager.modules(cdpAddress);
    let [phoMinted, startTime, status] = moduleData.slice(-3);
    let balances = await execute(`cast call --rpc-url ${cli.providerUrl} ${cdpAddress} "pool()((uint256,uint256))"`);
    let feesCollected = await execute(`cast call --rpc-url ${cli.providerUrl} ${cdpAddress} "feesCollected()(uint256)"`);

    const table = new Table({
        head: [moduleName, 'Result'],
        colWidths: [30, 50]
    })

    let [totalDebt, totalCollateral] = balances.substring(1, balances.length - 1).split(",");
    let collRatio = await execute(`cast call --rpc-url ${cli.providerUrl} ${cdpAddress} "computeCR(uint256,uint256)(uint256)" ${totalCollateral} ${totalDebt}`);

    table.push(["Address", cdpAddress]);
    table.push(["PHO Mined", phoMinted.toLocaleString()]);
    table.push(["startTime", startTime.toString()]);
    table.push(["status", status.toString()]);
    table.push(["Total Collateral", totalCollateral]);
    table.push(["Total Debt", totalDebt]);
    table.push(["Collateral Ratio", collRatio.toString()])
    logger.info(table.toString())

}

export const overviewCommand = {
    command: 'overview [tokenType]',
    describe: 'CDP Mechanism overview',
    handler: async (argv: CLIArgs): Promise<void> => {
      return await getOverview(await loadEnv(argv), argv)
    }
  }