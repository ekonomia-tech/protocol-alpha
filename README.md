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

## Deploying to the persistent mainnet fork on Render
TODO!

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