import Table from 'cli-table3'
import { loadEnv } from '../../../env'
import { logger } from '../../../logging'
import { ContractFunction, ethers } from 'ethers'
import { getters } from './get'
import { CLIArgs, CLIEnvironment } from '../../../types'
import { coreContracts } from '../../../defaults'
import { getNetworkContractAddresses } from '../../../helpers'

export const listProtocolParams = async (cli: CLIEnvironment): Promise<void> => {
  for (const name of coreContracts) {
    const table = new Table({
      head: [name, 'Result'],
      colWidths: [30, 50]
    })

    if (!(name in cli.contracts)) {
      continue
    }

    table.push(['Address', cli.contracts[name].address])

    const req: Array<Promise<any>> = []
    for (const fn of Object.values(getters)) {
      if (fn.contract !== name) continue
      const contract = cli.contracts[fn.contract]
      if (contract.interface.getFunction(fn.name).inputs.length === 0) {
        const contractFn: ContractFunction = contract.functions[fn.name]
        req.push(
          contractFn().then((values) => {
            let [value] = values
            if (typeof value === 'object') {
              value = value.toString()
            }
            table.push([fn.name, value])
          })
        )
      }
    }
    await Promise.all(req)
    logger.info(table.toString())
  }

  const { ModuleManager } = cli.contracts
  const { c: networkId } = cli.argv
  const { modules } = getNetworkContractAddresses(networkId)

  for (const [name, address] of Object.entries(modules)) {
    const moduleData = await ModuleManager.modules(address)
    if (moduleData.status === 0) return
    const table = new Table({
      head: [name, 'Result'],
      colWidths: [30, 50]
    })

    table.push(['Address', address])
    Object.entries(moduleData)
      .slice(-6)
      .forEach(([name, value]) => {
        let stringValue = value.toString()
        if (['phoCeiling', 'phoMinted', 'upcomingCeiling'].includes(name)) {
          stringValue = ethers.utils.formatEther(value)
        }
        table.push([name, stringValue])
      })

    logger.info(table.toString())
  }
}

export const listCommand = {
  command: 'list',
  describe: 'List protocol parameters',
  handler: async (argv: CLIArgs): Promise<void> => {
    return await listProtocolParams(await loadEnv(argv))
  }
}
