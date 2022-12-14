import yargs, { Argv } from 'yargs'
import { fastForwardCommand } from './fastForward'

// TODO: print help with fn signature
// TODO: add gas price

export const evmCommand = {
  command: 'evm',
  describe: 'EVM manipulation',
  builder: (yargs: Argv): yargs.Argv => {
    return yargs.command(fastForwardCommand)
  },
  handler: (): void => {
    yargs.showHelp()
  }
}
