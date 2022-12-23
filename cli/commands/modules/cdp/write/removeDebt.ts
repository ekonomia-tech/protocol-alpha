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
    logger.error('removeDebt: Collateral token does not have a corresponding CDP')
    return {} as CDPDebtParams
  }
  let contractAddress = getModuleAddress(networkId, 'cdp', collateralToken, "default")
  console.log(contractAddress)

  if (collateralToken == 'wsteth') {
    parameters = parameters.slice(1)
  }

  if (parameters.length != 1) {
    logger.error('removeDebt: Not enough parameters were supplied')
    return {} as CDPDebtParams
  }

  if (isNaN(parameters[0])) {
    logger.error('removeDebt: parameters supplied are in the wrong type')
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

const removeDebt = async (cli: CLIEnvironment, cliArgs: CLIArgs) => {
  let params: CDPDebtParams = getParams(cliArgs)
  if (!params.collateralToken) {
    logger.error('removeDebt: bad parameters')
    return
  }
  let { PHO: phoAddress, Kernel: kernelAddress} = addresses[cli.argv.c].core;
  let moduleName = moduleDictionary.cdp[params.collateralToken].default;
  let cdpAddress = addresses[cli.argv.c].modules[moduleName];


  if (cli.argv.c === 42069) {
    let approveCommand = `cast send --rpc-url ${cli.providerUrl} ${phoAddress} "approve(address,uint256)" ${kernelAddress} ${params.debtAmount} --from ${cli.wallet.address} --json`
    let res = JSON.parse(await execute(approveCommand))
    if (res.status == '0x1') {
      logger.info(
        `${cli.wallet.address} approved ${params.debtAmount} for ${params.contractAddress}`
      )
    }
  }

  let removeDebtCommand = `cast send --rpc-url ${cli.providerUrl} ${cdpAddress} "removeDebt(uint256)" ${params.debtAmount} --from ${cli.wallet.address} --json`
  let receipt = JSON.parse(await execute(removeDebtCommand));
  if (receipt.status == '0x1') {
    logger.info(`Removed debt from position for ${cli.wallet.address} successfully.`)
    let positionCommand = `cast call --rpc-url ${cli.providerUrl} ${cdpAddress} "cdps(address)((uint256,uint256))" ${cli.wallet.address}`
    let positionReceipt = await execute(positionCommand)
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
