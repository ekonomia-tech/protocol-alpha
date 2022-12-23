import yargs, { Argv } from 'yargs'
import { loadEnv } from '../../env'
import { CLIArgs, CLIEnvironment } from '../../types'
import { execute } from '../deploy'

const buildHelp = (): string => {
  const help = 'To fast forward -> evm fast-forward [seconds] [minutes] [hours]'
  return help
}

export const mine = async (cli: CLIEnvironment): Promise<void> => {
  await execute(
    `curl -H "Content-Type: application/json" -X POST --data '{"jsonrpc":"2.0","method":"evm_mine","params":[],"id":67}' ${cli.providerUrl}`
  )
}

export const mineCommand = {
  command: 'mine',
  describe: 'deploy contracts from deployParams.json',
  builder: (yargs: Argv): yargs.Argv => {
    return yargs.usage(buildHelp())
  },
  handler: async (argv: CLIArgs): Promise<void> => {
    return await mine(await loadEnv(argv))
  }
}
