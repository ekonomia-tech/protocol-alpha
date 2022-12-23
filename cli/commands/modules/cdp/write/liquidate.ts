import { ethers } from 'ethers'
import { moduleDictionary, tokenAddresses } from '../../../../defaults'
import { loadEnv } from '../../../../env'
import { getModuleAddress } from '../../../../helpers'
import { logger } from '../../../../logging'
import { CDPLiquidationParams, CLIArgs, CLIEnvironment } from '../../../../types'
import { execute } from '../../../deploy'
import addresses from '../../../../../addresses.json'
import { cli } from 'winston/lib/winston/config'
import { number } from 'yargs'

const getParams = (cli: CLIEnvironment, cliArgs: CLIArgs): CDPLiquidationParams => {
  let { _: parameters, c: networkId } = cliArgs
  parameters = parameters.slice(3)
  let collateralToken = parameters[0]
  if (!moduleDictionary.cdp[collateralToken]) {
    logger.error('liquidate: Collateral token does not have a corresponding CDP')
    return {} as CDPLiquidationParams
  }
  let contractAddress = getModuleAddress(networkId, 'cdp', collateralToken, "default")
  let cdpOwner = parameters[1];

  if (!cdpOwner) {
    logger.error('liquidate: missing cdp owner address');
    return {} as CDPLiquidationParams; 
  }

  return {
    contractAddress,
    collateralToken,
    depositToken: "",
    cdpOwner: cdpOwner,
    liquidator: cli.wallet.address
  }
}

const liquidate = async (cli: CLIEnvironment, cliArgs: CLIArgs) => {
  let params: CDPLiquidationParams = getParams(cli, cliArgs)
  if (!params.collateralToken) {
    logger.error('liquidate: bad parameters')
    return
  }
  let { PHO: phoAddress, Kernel: kernelAddress} = addresses[cli.argv.c].core;
  let moduleName = moduleDictionary.cdp[params.collateralToken].default;
  let cdpAddress = addresses[cli.argv.c].modules[moduleName];

  let positionCommand = `cast call --rpc-url ${cli.providerUrl} ${cdpAddress} "cdps(address)((uint256,uint256))" ${params.cdpOwner}`
  let positionResponse = await execute(positionCommand);
  let [ debtAmount, collateralAmount ]  = positionResponse.substring(1, positionResponse.length - 1).split(",");
  
  let collRatio = await execute(`cast call --rpc-url ${cli.providerUrl} ${cdpAddress} "computeCR(uint256,uint256)(uint256)" ${collateralAmount} ${debtAmount}`);
  let minCR = await execute(`cast call --rpc-url ${cli.providerUrl} ${cdpAddress} "minCR()(uint256)"`);

  if (Number(collRatio) >= Number(minCR)) {
    logger.error(`Collateral ratio is ${collRatio.substring(0,3)}% and not in liquidation zone. Liquidation aborted`);
    return;
  }
  
  logger.info(`Collateral Ratio: ${collRatio.substring(0,3)}%. Executing liquidation...`)

  if (cli.argv.c === 42069) {
    let approveCommand = `cast send --rpc-url ${cli.providerUrl} ${phoAddress} "approve(address,uint256)" ${kernelAddress} ${debtAmount} --from ${params.liquidator} --json`
    let res = JSON.parse(await execute(approveCommand))
    if (res.status == '0x1') {
      logger.info(
        `${params.liquidator} approved ${debtAmount} for ${params.contractAddress}`
      )
    }
  }

  let liquidateCommand = `cast send --rpc-url ${cli.providerUrl} ${cdpAddress} "liquidate(address)" ${params.cdpOwner} --from ${params.liquidator} --json`
  let receipt = JSON.parse(await execute(liquidateCommand));
  if (receipt.status == '0x1') {
    logger.info(`Liquidated position for ${cli.wallet.address} by ${params.liquidator} successfully.`)
  }
}


export const liquidateCommand = {
  command: 'liquidate',
  describe: 'liquidate a position',
  handler: async (argv: CLIArgs): Promise<void> => {
    return await liquidate(await loadEnv(argv), argv)
  }
}
