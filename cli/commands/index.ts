import yargs, { Argv } from 'yargs'

import { listCommand } from './list'
import { getCommand } from './get'
import { deployCommand } from './deploy'
import { addModuleCommand, executePHOUpdateCommand, updateModuleCeilingCommand } from './module'
import { fastForwardCommand } from './evm_manipulation'

export interface ProtocolFunction {
  contract: string
  name: string
}

// TODO: print help with fn signature
// TODO: add gas price


export const evmCommand = {
  command: 'evm',
  describe: 'EVM manipulation',
  builder: (yargs: Argv): yargs.Argv => {
    return yargs
      .command(fastForwardCommand)
  },
  handler: (): void => {
    yargs.showHelp()
  },
}

export const moduleCommand = {
  command: 'module',
  describe: 'module manipulation',
  builder: (yargs: Argv): yargs.Argv => {
    return yargs
      .command(addModuleCommand)
      .command(updateModuleCeilingCommand)
      .command(executePHOUpdateCommand)
  },
  handler: (): void => {
    yargs.showHelp()
  },
}
