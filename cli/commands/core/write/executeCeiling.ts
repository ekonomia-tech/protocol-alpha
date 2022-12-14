import yargs, { Argv } from 'yargs'
import { logger } from '../../../logging'
import { loadEnv } from '../../../env'
import { execute, generateForgeCommand, generateSignature } from '../../deploy'
import { verifyModule } from '../../../helpers'
import { CLIArgs, CLIEnvironment, CommandParams } from '../../../types'

const buildHelp = (): string => {
  const help = 'To execute module ceiling -> core execute-ceiling [moduleId]'
  return help
}

export const executeCeilingUpdate = async (
  cli: CLIEnvironment,
  cliArgs: CLIArgs
): Promise<void> => {
  const { c: networkId, moduleId } = cliArgs

  if (!verifyModule(networkId, moduleId)) return

  const sig: string = await generateSignature([
    {
      type: 'string',
      value: networkId.toString()
    },
    {
      type: 'address',
      value: moduleId
    }
  ])

  const commandParams: CommandParams = {
    contractName: 'UpdateExecuteCeilingUpdate',
    forkUrl: cli.providerUrl,
    privateKey: cli.wallet.privateKey,
    sig,
    networkId
  }
  const forgeCommand = generateForgeCommand(commandParams)
  await execute(forgeCommand)

  logger.info(`Successfully updated ceiling for module ${moduleId as string}`)
}

export const executePHOUpdateCommand = {
  command: 'execute-ceiling [moduleId]',
  describe: 'Executes ceiling update for a module',
  builder: (yargs: Argv): yargs.Argv => {
    return yargs.usage(buildHelp())
  },
  handler: async (argv: CLIArgs): Promise<void> => {
    return await executeCeilingUpdate(await loadEnv(argv), argv)
  }
}
