import { Options } from 'yargs'
import { Overrides } from 'ethers'

export const local = {
  mnemonic: 'myth like bonus scare over problem client lizard pioneer submit female collect',
  providerUrl: 'http://localhost:8545',
  accountNumber: '0',
}

// Used if having trouble pushing to goerli or mainnet
export const defaultOverrides: Overrides = {
  //  gasPrice: utils.parseUnits('25', 'gwei'), // auto
  //  gasLimit: 2000000, // auto
}

export const cliOpts = {
  providerUrl: {
    alias: 'provider-url',
    description: 'The URL of an Ethereum provider',
    type: 'string',
    group: 'Ethereum',
    default: local.providerUrl,
  },
  mnemonic: {
    alias: 'mnemonic',
    description: 'The mnemonic for an account which will pay for gas',
    type: 'string',
    group: 'Ethereum',
    default: local.mnemonic,
  },
  accountNumber: {
    alias: 'account-number',
    description: 'The account number of the mnemonic',
    type: 'string',
    group: 'Ethereum',
    default: local.accountNumber,
  },
} as { [key: string]: Options }