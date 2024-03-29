import yargs, { Argv } from 'yargs'
import { loadEnv } from '../../env'
import { CLIArgs, CLIEnvironment } from '../../types'
import { execute } from '../deploy'
import { logger } from '../../logging'

const buildHelp = (): string => {
  const help = 'To fast forward -> evm fast-forward [seconds] [minutes] [hours]'
  return help
}

export const fastForward = async (cli: CLIEnvironment, cliArgs: CLIArgs): Promise<void> => {
  const { seconds, hours, days } = cli.argv
  let toJump: number = seconds
  if (hours) {
    toJump += hours * 3600
  }
  if (days) {
    toJump += days * 86400
  }
  await execute(
    `curl -H "Content-Type: application/json" -X POST --data '{"jsonrpc":"2.0","method":"evm_increaseTime","params":[${toJump.toString()}],"id":67}' ${
      cli.providerUrl
    }`
  )
  await execute(
    `curl -H "Content-Type: application/json" -X POST --data '{"jsonrpc":"2.0","method":"evm_mine","params":[],"id":67}' ${cli.providerUrl}`
  )
  logger.info(`Jumped MAINNET_FORK up by ${toJump.toString()} seconds`)
}

export const fastForwardCommand = {
  command: 'fast-forward [seconds] [hours] [days]',
  describe: 'deploy contracts from deployParams.json',
  builder: (yargs: Argv): yargs.Argv => {
    return yargs.usage(buildHelp())
  },
  handler: async (argv: CLIArgs): Promise<void> => {
    return await fastForward(await loadEnv(argv), argv)
  }
}
