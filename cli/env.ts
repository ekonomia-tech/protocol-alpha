import { utils, Wallet, Overrides } from 'ethers'
import { logger } from './logging'
import { getProvider } from './network'
import { getContracts } from './contracts'
import { defaultOverrides } from './defaults'
import { getNetworkContractAddresses, getNetworkRPC, verifyNetwork } from './helpers'
import { CLIArgs, CLIEnvironment, PhotonContracts } from './types'

const { formatEther } = utils

export const displayGasOverrides = (): Overrides => {
  const r = { gasPrice: 'auto', gasLimit: 'auto', ...defaultOverrides }
  return r
}

export const loadEnv = async (argv: CLIArgs): Promise<CLIEnvironment> => {
  try {
    const providerUrl = getNetworkRPC(argv.c)

    const wallet: Wallet = Wallet.fromMnemonic(
      argv.mnemonic as string,
      `m/44'/60'/0'/0/${argv.accountNumber as number}`
    ).connect(getProvider(providerUrl))

    const balance = await wallet.getBalance()
    const chainId = (await wallet.provider.getNetwork()).chainId
    const nonce = await wallet.getTransactionCount()
    const walletAddress = await wallet.getAddress()
    const { c: networkId } = argv
    if (!verifyNetwork(networkId)) {
      logger.info(`Network id ${networkId} is invalid`)
    }

    const { core: coreContracts, modules: modulesContracts } =
      getNetworkContractAddresses(networkId)
    const contracts = coreContracts
      ? getContracts({ ...coreContracts, ...modulesContracts }, wallet)
      : ({} as PhotonContracts)

    logger.info(`Preparing contracts on chain id: ${chainId}`)
    logger.info(
      `Connected Wallet: address=${walletAddress} nonce=${nonce} balance=${formatEther(balance)}\n`
    )
    logger.info(`Gas settings: ${JSON.stringify(displayGasOverrides())}`)

    return {
      balance,
      chainId,
      nonce,
      walletAddress,
      wallet,
      contracts,
      argv,
      providerUrl
    }
  } catch (err) {
    logger.info(err)
    throw err
  }
}
