import { moduleDictionary } from '../../../../defaults'
import { loadEnv } from '../../../../env'
import { getModuleAddress } from '../../../../helpers'
import { logger } from '../../../../logging'
import { CDPLiquidationParams, CLIArgs, CLIEnvironment } from '../../../../types'
import { execute } from '../../../deploy'
import addresses from '../../../../../addresses.json'

const getParams = (cli: CLIEnvironment, cliArgs: CLIArgs): CDPLiquidationParams => {
  let { _: parameters, c: networkId } = cliArgs
  parameters = parameters.slice(3)
  const collateralToken = parameters[0]
  if (!moduleDictionary.cdp[collateralToken]) {
    logger.error('liquidate: Collateral token does not have a corresponding CDP')
    return {} as CDPLiquidationParams
  }
  const contractAddress: string = getModuleAddress(networkId, 'cdp', collateralToken, 'default')
  const cdpOwner = parameters[1]

  if (!cdpOwner) {
    logger.error('liquidate: missing cdp owner address')
    return {} as CDPLiquidationParams
  }

  return {
    contractAddress,
    collateralToken,
    depositToken: '',
    cdpOwner,
    liquidator: cli.wallet.address
  }
}

const liquidate = async (cli: CLIEnvironment, cliArgs: CLIArgs): Promise<void> => {
  const params: CDPLiquidationParams = getParams(cli, cliArgs)
  if (!params.collateralToken) {
    logger.error('liquidate: bad parameters')
    return
  }
  const { PHO: phoAddress, Kernel: kernelAddress }: Record<string, string> =
    addresses[cli.argv.c].core
  const moduleName: string = moduleDictionary.cdp[params.collateralToken].default
  const cdpAddress: string = addresses[cli.argv.c].modules[moduleName]

  const positionCommand: string = `cast call --rpc-url ${cli.providerUrl} ${cdpAddress} "cdps(address)((uint256,uint256))" ${params.cdpOwner}`
  const positionResponse = await execute(positionCommand)
  const [debtAmount, collateralAmount]: string[] = positionResponse
    .substring(1, positionResponse.length - 1)
    .split(',')

  const collRatio: string = await execute(
    `cast call --rpc-url ${cli.providerUrl} ${cdpAddress} "computeCR(uint256,uint256)(uint256)" ${collateralAmount} ${debtAmount}`
  )
  const minCR: string = await execute(
    `cast call --rpc-url ${cli.providerUrl} ${cdpAddress} "minCR()(uint256)"`
  )

  if (Number(collRatio) >= Number(minCR)) {
    logger.error(
      `Collateral ratio is ${collRatio.substring(
        0,
        3
      )}% and not in liquidation zone. Liquidation aborted`
    )
    return
  }

  logger.info(`Collateral Ratio: ${collRatio.substring(0, 3)}%. Executing liquidation...`)

  if (cli.argv.c === 42069) {
    const approveCommand: string = `cast send --rpc-url ${cli.providerUrl} ${phoAddress} "approve(address,uint256)" ${kernelAddress} ${debtAmount} --from ${params.liquidator} --json`
    const res = JSON.parse(await execute(approveCommand))
    if (res.status === '0x1') {
      logger.info(
        `${params.liquidator} approved ${debtAmount.toString()} for ${params.contractAddress}`
      )
    }
  }

  const liquidateCommand: string = `cast send --rpc-url ${cli.providerUrl} ${cdpAddress} "liquidate(address)" ${params.cdpOwner} --from ${params.liquidator} --json`
  const receipt = JSON.parse(await execute(liquidateCommand))
  if (receipt.status === '0x1') {
    logger.info(
      `Liquidated position for ${cli.wallet.address} by ${params.liquidator} successfully.`
    )
  }
}

export const liquidateCommand = {
  command: 'liquidate',
  describe: 'liquidate a position',
  handler: async (argv: CLIArgs): Promise<void> => {
    return await liquidate(await loadEnv(argv), argv)
  }
}
