import { ethers } from 'ethers'
import { moduleDictionary } from '../../../../defaults'
import { loadEnv } from '../../../../env'
import { getModuleAddress } from '../../../../helpers'
import { logger } from '../../../../logging'
import { CDPDebtParams, CLIArgs, CLIEnvironment } from '../../../../types'
import { execute } from '../../../deploy'
import addresses from '../../../../../addresses.json'

const getParams = (cliArgs: CLIArgs): CDPDebtParams => {
  let { _: parameters, c: networkId } = cliArgs
  parameters = parameters.slice(3)
  const collateralToken = parameters[0]
  if (!moduleDictionary.cdp[collateralToken]) {
    logger.error('removeDebt: Collateral token does not have a corresponding CDP')
    return {} as CDPDebtParams
  }
  const contractAddress = getModuleAddress(networkId, 'cdp', collateralToken, 'default')
  console.log(contractAddress)

  if (collateralToken === 'wsteth') {
    parameters = parameters.slice(1)
  }

  if (parameters.length !== 1) {
    logger.error('removeDebt: Not enough parameters were supplied')
    return {} as CDPDebtParams
  }

  if (isNaN(parameters[0])) {
    logger.error('removeDebt: parameters supplied are in the wrong type')
    return {} as CDPDebtParams
  }

  const debtAmount = ethers.utils.parseUnits(parameters[0], 18)

  return {
    contractAddress,
    collateralToken,
    depositToken: '',
    debtAmount
  }
}

const removeDebt = async (cli: CLIEnvironment, cliArgs: CLIArgs): Promise<void> => {
  const params: CDPDebtParams = getParams(cliArgs)
  if (!params.collateralToken) {
    logger.error('removeDebt: bad parameters')
    return
  }
  const { PHO: phoAddress, Kernel: kernelAddress }: Record<string, string> =
    addresses[cli.argv.c].core
  const moduleName: string = moduleDictionary.cdp[params.collateralToken].default
  const cdpAddress: string = addresses[cli.argv.c].modules[moduleName]

  if (cli.argv.c === 42069) {
    const approveCommand: string = `cast send --rpc-url ${
      cli.providerUrl
    } ${phoAddress} "approve(address,uint256)" ${kernelAddress} ${params.debtAmount.toString()} --from ${
      cli.wallet.address
    } --json`
    const res = JSON.parse(await execute(approveCommand))
    if (res.status === '0x1') {
      logger.info(
        `${cli.wallet.address} approved ${params.debtAmount.toString()} for ${
          params.contractAddress
        }`
      )
    }
  }

  const removeDebtCommand: string = `cast send --rpc-url ${
    cli.providerUrl
  } ${cdpAddress} "removeDebt(uint256)" ${params.debtAmount.toString()} --from ${
    cli.wallet.address
  } --json`
  const receipt = JSON.parse(await execute(removeDebtCommand))
  if (receipt.status === '0x1') {
    logger.info(`Removed debt from position for ${cli.wallet.address} successfully.`)
    const positionCommand: string = `cast call --rpc-url ${cli.providerUrl} ${cdpAddress} "cdps(address)((uint256,uint256))" ${cli.wallet.address}`
    const positionReceipt = await execute(positionCommand)
    logger.info(positionReceipt)
  }
}

export const removeDebtCommand = {
  command: 'remove-debt',
  describe: 'Remove debt from a position',
  handler: async (argv: CLIArgs): Promise<void> => {
    return await removeDebt(await loadEnv(argv), argv)
  }
}
