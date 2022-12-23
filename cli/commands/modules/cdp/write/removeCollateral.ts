import { ethers } from 'ethers'
import { moduleDictionary } from '../../../../defaults'
import { loadEnv } from '../../../../env'
import { getModuleAddress } from '../../../../helpers'
import { logger } from '../../../../logging'
import { CDPCollateralParams, CLIArgs, CLIEnvironment } from '../../../../types'
import { execute } from '../../../deploy'
import addresses from '../../../../../addresses.json'

const getParams = (cliArgs: CLIArgs): CDPCollateralParams => {
  let { _: parameters, c: networkId } = cliArgs
  parameters = parameters.slice(3)
  const collateralToken = parameters[0]
  if (!moduleDictionary.cdp[collateralToken]) {
    logger.error('removeCollateral: Collateral token does not have a corresponding CDP')
    return {} as CDPCollateralParams
  }
  const contractAddress = getModuleAddress(networkId, 'cdp', collateralToken, 'default')

  if (collateralToken === 'wsteth') {
    parameters = parameters.slice(1)
  }

  if (parameters.length !== 1) {
    logger.error('removeCollateral: Not enough parameters were supplied')
    return {} as CDPCollateralParams
  }

  if (isNaN(parameters[0])) {
    logger.error('removeCollateral: parameters supplied are in the wrong type')
    return {} as CDPCollateralParams
  }

  const collateralAmount = ethers.utils.parseUnits(parameters[0], 18)

  return {
    contractAddress,
    collateralToken,
    depositToken: parameters[0],
    collateralAmount
  }
}

const removeCollateral = async (cli: CLIEnvironment, cliArgs: CLIArgs): Promise<void> => {
  const params: CDPCollateralParams = getParams(cliArgs)
  if (!params.collateralToken) {
    logger.error('removeCollateral: bad parameters')
    return
  }
  const cdpAddress: string = addresses[cli.argv.c].modules.CDPPool_wstETH
  const removeCollateralCommand: string = `cast send --rpc-url ${
    cli.providerUrl
  } ${cdpAddress} "removeCollateral(uint256)" ${params.collateralAmount.toString()} --from ${
    cli.wallet.address
  } --json`
  const receipt = JSON.parse(await execute(removeCollateralCommand))
  if (receipt.status === '0x1') {
    logger.info(`Remove collateral from position for ${cli.wallet.address} successfully.`)
    const positionCommand: string = `cast call --rpc-url ${cli.providerUrl} ${cdpAddress} "cdps(address)((uint256,uint256))" ${cli.wallet.address}`
    const positionReceipt = await execute(positionCommand)
    logger.info(positionReceipt)
  }
}

export const removeCollateralCommand = {
  command: 'remove-collateral',
  describe: 'Remove collateral from a position',
  handler: async (argv: CLIArgs): Promise<void> => {
    return await removeCollateral(await loadEnv(argv), argv)
  }
}
