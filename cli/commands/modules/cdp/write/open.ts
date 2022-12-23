import { ethers } from 'ethers'
import { moduleDictionary, tokenAddresses } from '../../../../defaults'
import { loadEnv } from '../../../../env'
import { getModuleAddress } from '../../../../helpers'
import { logger } from '../../../../logging'
import { CDPOpenParams, CLIArgs, CLIEnvironment } from '../../../../types'
import { execute } from '../../../deploy'
import addresses from '../../../../../addresses.json'

const getParams = (cliArgs: CLIArgs): CDPOpenParams => {
  let { _: parameters, c: networkId } = cliArgs
  parameters = parameters.slice(3)
  const collateralToken = parameters[0]
  if (!moduleDictionary.cdp[collateralToken]) {
    logger.error('openPosition: Collateral token does not have a corresponding CDP')
    return {} as CDPOpenParams
  }
  const contractAddress = getModuleAddress(networkId, 'cdp', collateralToken, 'deposit')

  if (collateralToken === 'wsteth') {
    parameters = parameters.slice(1)
  }

  if (parameters.length !== 3) {
    logger.error('openPosition: Not enough parameters were supplied')
    return {} as CDPOpenParams
  }

  if (isNaN(parameters[1]) || isNaN(parameters[2])) {
    logger.error('openPositions: parameters supplied are in the wrong type')
    return {} as CDPOpenParams
  }

  const collateralAmount = ethers.utils.parseUnits(parameters[1], 18)
  const debtAmount = ethers.utils.parseUnits(parameters[2], 18)

  return {
    contractAddress,
    collateralToken,
    depositToken: parameters[0],
    collateralAmount,
    debtAmount
  }
}

const openPosition = async (cli: CLIEnvironment, cliArgs: CLIArgs): Promise<void> => {
  const params: CDPOpenParams = getParams(cliArgs)
  if (!params.collateralToken) {
    logger.error('openPosition: bad parameters')
    return
  }
  if (params.collateralToken === 'wsteth') {
    return await depositWithWrapper(params, cli)
  }
}

const depositWithWrapper = async (params: CDPOpenParams, cli: CLIEnvironment): Promise<void> => {
  const depositTokenAddress: string = tokenAddresses[params.depositToken]
  if (!depositTokenAddress) {
    logger.error('openPosition: deposit token address not found')
    return
  }

  if (cli.argv.c === 42069) {
    const approveCommand: string = `cast send --rpc-url ${
      cli.providerUrl
    } ${depositTokenAddress} "approve(address,uint256)" ${
      params.contractAddress
    } ${params.collateralAmount.toString()} --from ${cli.wallet.address} --json`
    const res = JSON.parse(await execute(approveCommand))
    if (res.status === '0x1') {
      logger.info(
        `${
          cli.wallet.address
        } approved ${params.collateralAmount.toString()} for ${depositTokenAddress}`
      )
    }
  }

  const openCommand: string = `cast send --rpc-url ${cli.providerUrl} ${
    params.contractAddress
  } "open(uint256,uint256,address)" ${params.collateralAmount.toString()} ${params.debtAmount.toString()} ${depositTokenAddress} --from ${
    cli.wallet.address
  } --json`
  const receipt = JSON.parse(await execute(openCommand))
  if (receipt.status === '0x1') {
    logger.info(`Open a new debt position for ${cli.wallet.address} successfully.`)
    const cdpAddress: string = addresses[cli.argv.c].modules.CDPPool_wstETH
    const positionCommand: string = `cast call --rpc-url ${cli.providerUrl} ${cdpAddress} "cdps(address)((uint256,uint256))" ${cli.wallet.address}`
    const positionReceipt = await execute(positionCommand)
    logger.info(positionReceipt)
  }
}

export const openCommand = {
  command: 'open',
  describe: 'opens a position',
  handler: async (argv: CLIArgs): Promise<void> => {
    return await openPosition(await loadEnv(argv), argv)
  }
}
