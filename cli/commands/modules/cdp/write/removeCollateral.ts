import { ethers } from 'ethers'
import { moduleDictionary, tokenAddresses } from '../../../../defaults'
import { loadEnv } from '../../../../env'
import { getModuleAddress } from '../../../../helpers'
import { logger } from '../../../../logging'
import { CDPCollateralParams, CDPOpenParams, CLIArgs, CLIEnvironment } from '../../../../types'
import { execute } from '../../../deploy'
import addresses from '../../../../../addresses.json'

const getParams = (cliArgs: CLIArgs): CDPCollateralParams => {
  let { _: parameters, c: networkId } = cliArgs
  parameters = parameters.slice(3)
  let collateralToken = parameters[0]
  if (!moduleDictionary.cdp[collateralToken]) {
    logger.error('removeCollateral: Collateral token does not have a corresponding CDP')
    return {} as CDPCollateralParams
  }
  let contractAddress = getModuleAddress(networkId, 'cdp', collateralToken, "default")

  if (collateralToken == 'wsteth') {
    parameters = parameters.slice(1)
  }

  if (parameters.length != 1) {
    logger.error('removeCollateral: Not enough parameters were supplied')
    return {} as CDPCollateralParams
  }

  if (isNaN(parameters[0])) {
    logger.error('removeCollateral: parameters supplied are in the wrong type')
    return {} as CDPCollateralParams
  }

  let collateralAmount = ethers.utils.parseUnits(parameters[0], 18)

  return {
    contractAddress,
    collateralToken,
    depositToken: parameters[0],
    collateralAmount
  }
}

const removeCollateral = async (cli: CLIEnvironment, cliArgs: CLIArgs) => {
  let params: CDPCollateralParams = getParams(cliArgs)
  if (!params.collateralToken) {
    logger.error('removeCollateral: bad parameters')
    return
  }
  let cdpAddress = addresses[cli.argv.c].modules['CDPPool_wstETH']; 
  let removeCollateralCommand = `cast send --rpc-url ${cli.providerUrl} ${cdpAddress} "removeCollateral(uint256)" ${params.collateralAmount} --from ${cli.wallet.address} --json`
  let receipt = JSON.parse(await execute(removeCollateralCommand));
  if (receipt.status == '0x1') {
    logger.info(`Remove collateral from position for ${cli.wallet.address} successfully.`)
    let positionCommand = `cast call --rpc-url ${cli.providerUrl} ${cdpAddress} "cdps(address)((uint256,uint256))" ${cli.wallet.address}`
    let positionReceipt = await execute(positionCommand)
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
