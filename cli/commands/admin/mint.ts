import { ethers, logger } from 'ethers'
import yargs, { Argv } from 'yargs'
import { loadEnv } from '../../env'
import { toPHO, sendTransaction } from '../../network'
import { CLIArgs, CLIEnvironment } from '../../types'
import { fastForward } from '../evm/fastForward'

const buildHelp = (): string => {
  const help = 'Mint PHO -> admin mint [to] [amount]'
  return help
}

export const mintPHO = async (cli: CLIEnvironment, cliArgs: CLIArgs): Promise<void> => {
  let { to, amount } = cliArgs
  const { ModuleManager, PHO } = cli.contracts
  const adminAddress = cli.wallet.address

  const moduleData = await ModuleManager.modules(adminAddress)
  if (!moduleData.status) {
    await sendTransaction(cli.wallet, ModuleManager, 'addModule', [adminAddress])
    await sendTransaction(cli.wallet, ModuleManager, 'setPHOCeilingForModule', [
      adminAddress,
      ethers.constants.MaxUint256
    ])
    cli.argv.seconds = await ModuleManager.moduleDelay()
    await fastForward(cli, cliArgs)
    await sendTransaction(cli.wallet, ModuleManager, 'executeCeilingUpdate', [adminAddress])
  }

  amount = toPHO(amount)
  await sendTransaction(cli.wallet, ModuleManager, 'mintPHO', [to, amount])
  logger.info(`Successfully minted $PHO to ${to as string}`)
  logger.info(`Current ${to as string} balance = ${(await PHO.balanceOf(to)).toString()}`)
}

export const mintCommand = {
  command: 'mint [to] [amount]',
  describe: 'Mint a certain amount to an address',
  builder: (yargs: Argv): yargs.Argv => {
    return yargs.usage(buildHelp())
  },
  handler: async (argv: CLIArgs): Promise<void> => {
    return await mintPHO(await loadEnv(argv), argv)
  }
}
