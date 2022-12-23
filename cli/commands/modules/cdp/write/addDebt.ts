import { ethers } from 'ethers'
import { moduleDictionary, tokenAddresses } from '../../../../defaults'
import { loadEnv } from '../../../../env'
import { getModuleAddress } from '../../../../helpers'
import { logger } from '../../../../logging'
import { CDPDebtParams, CLIArgs, CLIEnvironment } from '../../../../types'
import { execute } from '../../../deploy'
import addresses from '../../../../../addresses.json'

const getParams = (cliArgs: CLIArgs): CDPDebtParams => {
  let { _: parameters, c: networkId } = cliArgs
  parameters = parameters.slice(3)
  let collateralToken = parameters[0]
  if (!moduleDictionary.cdp[collateralToken]) {
    logger.error('addDebt: Collateral token does not have a corresponding CDP')
    return {} as CDPDebtParams
  }
  let contractAddress = getModuleAddress(networkId, 'cdp', collateralToken, "default")

  if (collateralToken == 'wsteth') {
    parameters = parameters.slice(1)
  }

  if (parameters.length != 1) {
    logger.error('addDebt: Not enough parameters were supplied')
    return {} as CDPDebtParams
  }

  if (isNaN(parameters[0])) {
    logger.error('addDebt: parameters supplied are in the wrong type')
    return {} as CDPDebtParams
  }

  let debtAmount = ethers.utils.parseUnits(parameters[0], 18)

  return {
    contractAddress,
    collateralToken,
    depositToken: "",
    debtAmount
  }
}

const addDebt = async (cli: CLIEnvironment, cliArgs: CLIArgs) => {
  let params: CDPDebtParams = getParams(cliArgs)
  if (!params.collateralToken) {
    logger.error('addDebt: bad parameters')
    return
  }
  let moduleName = moduleDictionary.cdp[params.collateralToken].default;
  let cdpAddress = addresses[cli.argv.c].modules[moduleName];

  let addDebtCommand = `cast send --rpc-url ${cli.providerUrl} ${cdpAddress} "addDebt(uint256)" ${params.debtAmount} --from ${cli.wallet.address} --json`
  let receipt = JSON.parse(await execute(addDebtCommand));
  if (receipt.status == '0x1') {
    logger.info(`Added debt to position for ${cli.wallet.address} successfully.`)
    let positionCommand = `cast call --rpc-url ${cli.providerUrl} ${cdpAddress} "cdps(address)((uint256,uint256))" ${cli.wallet.address}`
    let positionReceipt = await execute(positionCommand)
    logger.info(positionReceipt)
  }
}


export const addDebtCommand = {
  command: 'add-debt',
  describe: 'Add debt to a position',
  handler: async (argv: CLIArgs): Promise<void> => {
    return await addDebt(await loadEnv(argv), argv)
  }
}
