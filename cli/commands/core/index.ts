import yargs, { Argv } from 'yargs'
import { readCommand } from './read'
import { addModuleCommand, executePHOUpdateCommand, updateModuleCeilingCommand } from './write'

export const coreCommand = {
  command: 'core',
  describe: 'Photon protocol configuration',
  builder: (yargs: Argv): yargs.Argv => {
    return yargs
      .command(readCommand)
      .command(addModuleCommand)
      .command(updateModuleCeilingCommand)
      .command(executePHOUpdateCommand)
  },
  handler: (): void => {
    yargs.showHelp()
  }
}
