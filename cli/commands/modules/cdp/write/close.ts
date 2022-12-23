import { ethers } from 'ethers'
import { moduleDictionary, tokenAddresses } from '../../../../defaults'
import { loadEnv } from '../../../../env'
import { getModuleAddress } from '../../../../helpers'
import { logger } from '../../../../logging'
import { CDPBaseParams, CLIArgs, CLIEnvironment } from '../../../../types'
import { execute } from '../../../deploy'
import addresses from '../../../../../addresses.json'

const getParams = (cliArgs: CLIArgs): CDPBaseParams => {
  let { _: parameters, c: networkId } = cliArgs
  parameters = parameters.slice(3)
  let collateralToken = parameters[0]
  if (!moduleDictionary.cdp[collateralToken]) {
    logger.error('close: Collateral token does not have a corresponding CDP')
    return {} as CDPBaseParams
  }
  let contractAddress = getModuleAddress(networkId, 'cdp', collateralToken, "default")

  return {
    contractAddress,
    collateralToken,
    depositToken: ""
  }
}

const close = async (cli: CLIEnvironment, cliArgs: CLIArgs) => {
  let params: CDPBaseParams = getParams(cliArgs)
  if (!params.collateralToken) {
    logger.error('close: bad parameters')
    return
  }
  let { PHO: phoAddress, Kernel: kernelAddress} = addresses[cli.argv.c].core;
  let moduleName = moduleDictionary.cdp[params.collateralToken].default;
  let cdpAddress = addresses[cli.argv.c].modules[moduleName];

  let positionCommand = `cast call --rpc-url ${cli.providerUrl} ${cdpAddress} "cdps(address)((uint256,uint256))" ${cli.wallet.address}`
  let positionResponse = await execute(positionCommand);
  let debtAmount = positionResponse.substring(1,positionResponse.length - 1).split(",")[0];
 
  if (cli.argv.c === 42069) {
    let approveCommand = `cast send --rpc-url ${cli.providerUrl} ${phoAddress} "approve(address,uint256)" ${kernelAddress} ${debtAmount} --from ${cli.wallet.address} --json`
    let res = JSON.parse(await execute(approveCommand))
    if (res.status == '0x1') {
      logger.info(
        `${cli.wallet.address} approved ${debtAmount} for ${params.contractAddress}`
      )
    }
  }

  let closeCommand = `cast send --rpc-url ${cli.providerUrl} ${cdpAddress} "close()" --from ${cli.wallet.address} --json`
  let receipt = JSON.parse(await execute(closeCommand));
  if (receipt.status == '0x1') {
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
