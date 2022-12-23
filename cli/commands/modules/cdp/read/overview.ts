import Table from 'cli-table3'
import { logger } from 'ethers'
import { moduleDictionary } from '../../../../defaults'
import { loadEnv } from '../../../../env'
import { getModuleAddress } from '../../../../helpers'
import { CLIArgs, CLIEnvironment } from '../../../../types'
import { execute } from '../../../deploy'

const getOverview = async (cli: CLIEnvironment, cliArgs: CLIArgs): Promise<void> => {
  const moduleName = moduleDictionary.cdp[cliArgs.tokenType].default
  const cdpAddress = getModuleAddress(cliArgs.c, 'cdp', cliArgs.tokenType, 'default')

  const moduleData = await cli.contracts.ModuleManager.modules(cdpAddress)
  const [phoMinted, startTime, status] = moduleData.slice(-3)
  const balances = await execute(
    `cast call --rpc-url ${cli.providerUrl} ${cdpAddress} "pool()((uint256,uint256))"`
  )
  const feesCollected = await execute(
    `cast call --rpc-url ${cli.providerUrl} ${cdpAddress} "feesCollected()(uint256)"`
  )

  const table = new Table({
    head: [moduleName, 'Result'],
    colWidths: [30, 50]
  })

  const [totalDebt, totalCollateral]: string[] = balances
    .substring(1, balances.length - 1)
    .split(',')
  const collRatio: string = await execute(
    `cast call --rpc-url ${cli.providerUrl} ${cdpAddress} "computeCR(uint256,uint256)(uint256)" ${totalCollateral} ${totalDebt}`
  )

  table.push(['Address', cdpAddress])
  table.push(['PHO Mined', phoMinted.toLocaleString()])
  table.push(['startTime', startTime.toString()])
  table.push(['status', status.toString()])
  table.push(['Total Collateral', totalCollateral])
  table.push(['Total Debt', totalDebt])
  table.push(['Collateral Ratio', collRatio.toString()])
  table.push(['feesCollected', feesCollected])
  logger.info(table.toString())
}

export const overviewCommand = {
  command: 'overview [tokenType]',
  describe: 'CDP Mechanism overview',
  handler: async (argv: CLIArgs): Promise<void> => {
    return await getOverview(await loadEnv(argv), argv)
  }
}
