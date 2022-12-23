import yargs, { Argv } from 'yargs'
import { cdpCommand } from './cdp'

export const modulesCommand = {
  command: 'modules',
  describe: 'Photon protocol modules',
  builder: (yargs: Argv): yargs.Argv => {
    return yargs.command(cdpCommand)
  },
  handler: (): void => {
    yargs.showHelp()
  }
}
