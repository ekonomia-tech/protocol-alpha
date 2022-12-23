import { ethers } from 'ethers'
import { moduleDictionary, tokenAddresses } from '../../../../defaults'
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
    logger.error('addCollateral: Collateral token does not have a corresponding CDP')
    return {} as CDPCollateralParams
  }
  const contractAddress: string = getModuleAddress(networkId, 'cdp', collateralToken, 'deposit')

  if (collateralToken === 'wsteth') {
    parameters = parameters.slice(1)
    if (!['steth', 'weth', 'eth'].includes(parameters[0])) {
      logger.error('Deposit token is not supported')
      return {} as CDPCollateralParams
    }
  }

  if (parameters.length !== 2) {
    logger.error('addCollateral: Not enough parameters were supplied')
    return {} as CDPCollateralParams
  }

  if (isNaN(parameters[1])) {
    logger.error('addCollateral: parameters supplied are in the wrong type')
    return {} as CDPCollateralParams
  }

  const collateralAmount = ethers.utils.parseUnits(parameters[1], 18)

  return {
    contractAddress,
    collateralToken,
    depositToken: parameters[0],
    collateralAmount
  }
}

const addCollateral = async (cli: CLIEnvironment, cliArgs: CLIArgs): Promise<void> => {
  const params: CDPCollateralParams = getParams(cliArgs)
  if (!params.collateralToken) {
    logger.error('addCollateral: bad parameters')
    return
  }
  if (params.collateralToken === 'wsteth') {
    return await depositWithWrapper(params, cli)
  }
}

const depositWithWrapper = async (
  params: CDPCollateralParams,
  cli: CLIEnvironment
): Promise<void> => {
  const depositTokenAddress: string = tokenAddresses[params.depositToken]
  if (!depositTokenAddress) {
    logger.error('addCollateral: deposit token address not found')
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

  const addCollateralCommand = `cast send --rpc-url ${cli.providerUrl} ${
    params.contractAddress
  } "addCollateral(uint256,address)" ${params.collateralAmount.toString()} ${depositTokenAddress} --from ${
    cli.wallet.address
  } --json`
  const receipt = JSON.parse(await execute(addCollateralCommand))
  if (receipt.status === '0x1') {
    logger.info(`Added collateral to position for ${cli.wallet.address} successfully.`)
    const cdpAddress: string = addresses[cli.argv.c].modules.CDPPool_wstETH
    const positionCommand: string = `cast call --rpc-url ${cli.providerUrl} ${cdpAddress} "cdps(address)((uint256,uint256))" ${cli.wallet.address}`
    const positionReceipt: string = await execute(positionCommand)
    logger.info(positionReceipt)
  }
}

export const addCollateralCommand = {
  command: 'add-collateral',
  describe: 'Add collateral to a position',
  handler: async (argv: CLIArgs): Promise<void> => {
    return await addCollateral(await loadEnv(argv), argv)
  }
}
