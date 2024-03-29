import yargs, { Argv } from 'yargs'
import { logger } from '../../../logging'
import { loadEnv } from '../../../env'
import { ContractFunction } from 'ethers'
import { CLIArgs, CLIEnvironment, ProtocolFunction } from '../../../types'

// TODO
// add in module-specific getters, but maybe in another object. it would have to accept parameters
export const getters = {
  'pho-supply': { contract: 'PHO', name: 'totalSupply' },
  'pho-owner': { contract: 'PHO', name: 'owner' },
  'pho-kernel': { contract: 'PHO', name: 'kernel' },
  'ton-supply': { contract: 'TON', name: 'totalSupply' },
  'kernel-ton-governance': { contract: 'Kernel', name: 'pho' },
  'mm-pho-governance': { contract: 'ModuleManager', name: 'PHOGovernance' },
  'mm-ton-governance': { contract: 'ModuleManager', name: 'TONGovernance' },
  'mm-pause-guardian': { contract: 'ModuleManager', name: 'pauseGuardian' },
  'mm-module-delay': { contract: 'ModuleManager', name: 'moduleDelay' }
}

const buildHelp = (): string => {
  let help = '$0 protocol get <fn> [params]\n Photon protocol configuration\n\nCommands:\n\n'
  for (const entry of Object.keys(getters)) {
    help += '  $0 protocol get ' + entry + ' [params]\n'
  }
  return help
}

export const getProtocolParam = async (cli: CLIEnvironment, cliArgs: CLIArgs): Promise<void> => {
  logger.info(`Getting ${cliArgs.fn as string}...`)
  const fn: ProtocolFunction = getters[cliArgs.fn]
  if (!fn) {
    logger.error(`Command ${cliArgs.fn as string} does not exist`)
    return
  }

  // Parse params
  const params = cliArgs.params ? cliArgs.params.toString().split(',') : []

  // Send tx
  const contractFn: ContractFunction = cli.contracts[fn.contract].functions[fn.name]
  const [value] = await contractFn(...params)
  logger.info(`${fn.name} = ${value as string}`)
}

export const getCommand = {
  command: 'get <fn> [params]',
  describe: 'Get network parameter',
  builder: (yargs: Argv): yargs.Argv => {
    return yargs.usage(buildHelp())
  },
  handler: async (argv: CLIArgs): Promise<void> => {
    return await getProtocolParam(await loadEnv(argv), argv)
  }
}
