import Table from 'cli-table3'
import { logger } from 'ethers'
import { moduleDictionary } from '../../../../defaults'
import { loadEnv } from '../../../../env'
import { getModuleAddress } from '../../../../helpers'
import { CLIArgs, CLIEnvironment } from '../../../../types'
import { execute } from '../../../deploy'
import { toReadablePrice } from '../../../../helpers'

const getPosition = async (cli: CLIEnvironment, cliArgs: CLIArgs): Promise<void> => {
  const cdpOwner: string = cliArgs.cdpOwner;
  const moduleName = moduleDictionary.cdp[cliArgs.tokenType].default
  const cdpAddress = getModuleAddress(cliArgs.c, 'cdp', cliArgs.tokenType, 'default')

  let cdpData: string = await execute(`cast call --rpc-url ${cli.providerUrl} ${cdpAddress} "cdps(address)((uint256,uint256))" ${cdpOwner}`);
  let [ debt, collateral ]: string[] = cdpData.substring(1, cdpData.length -1).split(",")
  const collRatio: string = await execute(
    `cast call --rpc-url ${cli.providerUrl} ${cdpAddress} "computeCR(uint256,uint256)(uint256)" ${collateral} ${debt}`
  )

  const table = new Table({
    head: [moduleName, 'Result'],
    colWidths: [30, 50]
  })

  table.push(["CDP Owner", cdpOwner])
  table.push(["Debt", toReadablePrice(debt)]);
  table.push(["Collateral", toReadablePrice(collateral)])
  table.push(["Collateral Ratio", collRatio.slice(0, -3).concat("%")])
  logger.info(table.toString());
}

export const positionCommand = {
  command: 'position [tokenType] [cdpOwner]',
  describe: 'Get information regarding an open position',
  handler: async (argv: CLIArgs): Promise<void> => {
    return await getPosition(await loadEnv(argv), argv)
  }
}
