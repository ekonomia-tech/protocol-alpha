import { logger } from './logging'
import { NetworkContracts } from './types'
import addresses from '../addresses.json'
import { moduleDictionary, rpcUrls } from './defaults'

export const verifyModule = (networkId: number, moduleId: string): boolean => {
  try {
    const modules = addresses[networkId].modules
    const moduleAddresses = Object.values(modules)
    for (let i = 0; i < moduleAddresses.length; i++) {
      if (moduleAddresses[i] === moduleId) {
        return true
      }
    }
    logger.info('Could not find the module in addresses.json')
    return false
  } catch (err) {
    logger.info(`Error verifying module - ${err as string}`)
    return false
  }
}

export const verifyNetwork = (networkId: number): boolean => {
  if (!networkId) {
    logger.info('First parameter should be the network name')
    return false
  } else if (!getNetworkRPC(networkId)) {
    logger.error(`Network with ID ${networkId} does not have a RPC_URK record in the .env file`)
    return false
  }
  return true
}

export const getNetworkRPC = (networkId: number): string => {
  const rpcUrl = rpcUrls[networkId]
  if (!rpcUrl) {
    throw new Error(`Network id ${networkId} does not have a corresponding value in the .env file`)
  }
  return rpcUrl
}

export const getNetworkContractAddresses = (networkId: number): NetworkContracts => {
  return addresses[networkId]
}

export const getModuleAddress = (
  networkId: number,
  type: string,
  identifier: string,
  action: string
): string => {
  const contractName = moduleDictionary[type][identifier][action]
  if (!contractName || !verifyNetwork(networkId)) {
    logger.error('getModuleAddress: No module was found with the given params')
    return ''
  }
  const modules = addresses[networkId].modules
  if (!modules) {
    logger.error('getModuleAddress: Network does not have deployed contracts')
  }
  return modules[contractName]
}

export const toReadablePrice = (value: string): string => {
  return value.slice(0, value.length - 18) + "." + value.slice(-18);
}