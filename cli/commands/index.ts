import yargs, { Argv } from 'yargs'

import { listCommand } from './list'
import { getCommand } from './get'

export interface ProtocolFunction {
  contract: string
  name: string
}

// TODO: print help with fn signature
// TODO: add gas price

export const protocolCommand = {
  command: 'protocol',
  describe: 'Photon protocol configuration',
  builder: (yargs: Argv): yargs.Argv => {
    return yargs
      .command(getCommand)
      .command(listCommand)
  },
  handler: (): void => {
    yargs.showHelp()
  },
}
