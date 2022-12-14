import yargs, { Argv } from 'yargs'
import { logger } from '../../../logging'
import { loadEnv } from '../../../env'
import { execute, generateForgeCommand, generateSignature } from '../../deploy'
import { verifyModule } from '../../../helpers'
import { CLIArgs, CLIEnvironment, CommandParams } from '../../../types'

const buildHelp = (): string => {
  const help = 'To add a module -> core add [moduleId]'
  return help
}

export const addModule = async (cli: CLIEnvironment, cliArgs: CLIArgs): Promise<void> => {
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
    contractName: 'UpdateAddModule',
    forkUrl: cli.providerUrl,
    privateKey: cli.wallet.privateKey,
    sig,
    networkId
  }
  const forgeCommand = generateForgeCommand(commandParams)
  await execute(forgeCommand)

  logger.info(`Successfully added module ${moduleId as string}`)
}

export const addModuleCommand = {
  command: 'add [moduleId]',
  describe: 'Adds a module to module manager',
  builder: (yargs: Argv): yargs.Argv => {
    return yargs.usage(buildHelp())
  },
  handler: async (argv: CLIArgs): Promise<void> => {
    return await addModule(await loadEnv(argv), argv)
  }
}
