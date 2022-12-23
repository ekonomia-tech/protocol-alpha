import { moduleDictionary } from '../../../../defaults'
import { loadEnv } from '../../../../env'
import { getModuleAddress } from '../../../../helpers'
import { logger } from '../../../../logging'
import { CDPBaseParams, CLIArgs, CLIEnvironment } from '../../../../types'
import { execute } from '../../../deploy'
import addresses from '../../../../../addresses.json'

const getParams = (cliArgs: CLIArgs): CDPBaseParams => {
  let { _: parameters, c: networkId } = cliArgs
  parameters = parameters.slice(3)
  const collateralToken = parameters[0]
  if (!moduleDictionary.cdp[collateralToken]) {
    logger.error('close: Collateral token does not have a corresponding CDP')
    return {} as CDPBaseParams
  }
  const contractAddress: string = getModuleAddress(networkId, 'cdp', collateralToken, 'default')

  return {
    contractAddress,
    collateralToken,
    depositToken: ''
  }
}

const close = async (cli: CLIEnvironment, cliArgs: CLIArgs): Promise<void> => {
  const params: CDPBaseParams = getParams(cliArgs)
  if (!params.collateralToken) {
    logger.error('close: bad parameters')
    return
  }
  const { PHO: phoAddress, Kernel: kernelAddress }: Record<string, string> =
    addresses[cli.argv.c].core
  const moduleName: string = moduleDictionary.cdp[params.collateralToken].default
  const cdpAddress: string = addresses[cli.argv.c].modules[moduleName]

  const positionCommand: string = `cast call --rpc-url ${cli.providerUrl} ${cdpAddress} "cdps(address)((uint256,uint256))" ${cli.wallet.address}`
  const positionResponse = await execute(positionCommand)
  const debtAmount: string = positionResponse
    .substring(1, positionResponse.length - 1)
    .split(',')[0]

  if (cli.argv.c === 42069) {
    const approveCommand: string = `cast send --rpc-url ${cli.providerUrl} ${phoAddress} "approve(address,uint256)" ${kernelAddress} ${debtAmount} --from ${cli.wallet.address} --json`
    const res = JSON.parse(await execute(approveCommand))
    if (res.status === '0x1') {
      logger.info(`${cli.wallet.address} approved ${debtAmount} for ${params.contractAddress}`)
    }
  }

  const closeCommand: string = `cast send --rpc-url ${cli.providerUrl} ${cdpAddress} "close()" --from ${cli.wallet.address} --json`
  const receipt = JSON.parse(await execute(closeCommand))
  if (receipt.status === '0x1') {
    logger.info(`Closed position for ${cli.wallet.address} successfully.`)
  }
}

export const closeCommand = {
  command: 'close',
  describe: 'close a position',
  handler: async (argv: CLIArgs): Promise<void> => {
    return await close(await loadEnv(argv), argv)
  }
}
