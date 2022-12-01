# Protocol Alpha
Alpha version of the Photon Finance Decentralized Stablecoin protocol. Photon is a modular, risk and profit separated decentralized stablecoin.

## Setup and Building
To start the project, clone the repo to your local machine using the following CLI commands:

1. Clone the repo onto your local machine and install the submodules: `git clone --recursive <repo link>`

   > NOTE: If you have not installed the submodules, probably because you ran `git clone <repo link>` instead of the CLI command in step 1, you may run into errors when running `forge build` since it is looking for the dependencies for the project. `git submodule update --init --recursive` can be used if you clone the repo without installing the submodules.

2. Install forge on your machine if you have not already: `forge install`

> NOTE: If you need to download the latest version of foundry, just run `foundryup` 

3. Build the project and make sure everything compiles: `forge build`

## Testing Against Local Mainnet Fork
To run unit tests against a non-persistent local mainnet fork, first make sure you have a `.env` file set up at the root (follow `.env.example` format) and populate the `RPC_URL` variable like so:

`RPC_URL=<insert ETH RPC URL here>`

Make sure you are using latest version of foundry, so that it auto-sources `.env`, otherwise run (while in the root directory): `source .env`

CLI command: `forge test -vvv`

You can also test individual contracts with the following:
- `forge test --match-contract Kernel -vvv`
- Where `Kernel` is the name of the contract

## Deploying contracts on Local Mainnet Fork
To deploy the code onto a persistent mainnet fork, first make sure you have a `.env` file set up at the root (follow `.env.example` format):

- ```RPC_URL=<insert ETH RPC URL here>```
- ```FORK_URL=<insert your localhost fork url - usually http://localhost:8545>```
- ```PRIVATE_KEY=<should be the first private key supplied by anvil>```

# Deploying the base protocol contracts

1. run `source .env` in the base folder
2. open a new terminal and run `anvil --fork-url $RPC_URL`
3. copy the first private key from the given private keys into `.env`
4. run `source .env` to update the `PRIVATE_KEY`
5. open a new terminal and on the base folder run 
- ```forge script scripts/DeployProtocol.s.sol:DeployProtocol --fork-url $FORK_URL --broadcast --json  --private-key $PRIVATE_KEY```

- To find the deployed contracts' addresses, head over to `broadcast` folder and find the latest run log.

# Deploy Price Controller module

To deploy the price controller:
1. follow the `Addresses.example` template to update `Addresses.s.sol`:
- ```kernelAddress```
- ```moduleManagerAddress```
- ```phoAddress```
- ```tonAddress```

2. deploy a curve pool by running the following command:
- ```forge script scripts/DeployCurvePool.s.sol:DeployCurvePool --fork-url $FORK_URL --broadcast --json  --private-key $PRIVATE_KEY -vvvv```
3. copy the curve pool address from the printed log
4. run cast command to checksum the pool address
- ```cast to-checksum-address <pool address>```
5. add the checksum curve pool address to `Addresses.s.sol`
6. deploy the price controller by running the following command:
- ```forge script scripts/DeployPriceController.s.sol:DeployPriceController --fork-url $FORK_URL --broadcast --json  --private-key $PRIVATE_KEY -vvvv```

# Deploy the CDP Module using WETH as collateral

To deploy a CDP module with WETH as collateral, follow the following steps:
1. follow the `Addresses.example` template to update `Addresses.s.sol`:
- ```moduleManagerAddress```
- ```chainlinkOracleAddress```

2. deploy the CDP module using the ```DeployCDPModuleWETH.s.sol``` script by running:
- ```forge script scripts/DeployCDPModuleWETH.s.sol:DeployCDPModuleWETH --fork-url $FORK_URL --broadcast --json  --private-key $PRIVATE_KEY -vvvv```

# Register a module with the Module Manager

1. Use the ```PHOGovernance``` account to register a new module by running following command:
- ```cast send <module manager address> "addModule(address)" <deployed module address> --from <PHOGovernance address>``` 
2. User the ```TONGovernance``` account to grant a minting ceiling to the module by running the following command:
- ```cast send <module manager address> "setPHOCeilingForModule(address, uint256)" <deployed module address> <minting ceiling for module> --from <TONGovernance address>``` 

to verify the module has been registered and received a minting ceiling, run the following command:
```cast call <module manager address> "modules(address)((uint256,uint256,uint256))" <module address>```

# To run any command on the deployed contracts

```cast call --rpc-url <render endpoint> 0xc0Bb1650A8eA5dDF81998f17B5319afD656f4c11 "modules(address)((uint256,uint256,uint256))" 0xBbc18b580256A82dC0F9A86152b8B22E7C1C8005```

For syntax description, refer to the following link:
- https://book.getfoundry.sh/reference/cast/cast-call

## Deploying to the persistent mainnet fork on Render
TODO!

## Releasing / NPM Publication

The basic flow of cutting a release should occur according to the following steps:

- Run contract deploy scripts to generate new `addresses.json` artifact
- Update `package.json` version to latest [semver](https://semver.org/) version; `"version": "0.1.0"`,
- Commit with [semver](https://semver.org/) commit message, for example; `git commit -m "Release v0.1.0"`
- Tag release with corresponding release version from last step; `git tag v0.1.0`
- Push tag; `git push origin --tags`
- Cut a new [Github Release](https://github.com/ekonomia-tech/protocol-alpha/releases/new)
  - The title doesn't matter too much, but lead with the release version and include a basic sum up of the release; `v0.1.0 - We changed the game`
  - You can just autogenerate release notes
- Once published, the [publish.yml](./workflows/publish.yml) Github action should run automatically, only publishing if tests pass and the build completed successfully.

## Repo Configuration
### VSCode
If you are using Juan Blanco's [solidity](https://marketplace.visualstudio.com/items?itemName=JuanBlanco.solidity) extension on VSCode, you can use this settings:

```json
{
  "solidity.compileUsingRemoteVersion": "v0.8.13+commit.abaa5c0e"
}
```

### Remappings
In `remappings.txt` we have remapped the folder structure for cleaner imports. `remappings.txt` is read by `foundry` as well as Juan Blanco's Solidity extension, therefore eliminating the need for users to set local VScode settings for this repo.
