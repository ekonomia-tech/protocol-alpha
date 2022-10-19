# protocol-alpha

Alpha version of a DeFi stablecoin protocol

# What is the Protocol?

- We are working on a DeFi stablecoin protocol. The stablecoin is algorithmically / partially backed by collateral.
- We have our own novel ideas around reputation & other aspects of the protocol we are building.

# Developer Notes

To start the project, clone the repo to your local machine using the following CLI commands:

1. Clone the repo onto your local machine and install the submodules: `git clone --recursive <repo link>`

   > NOTE: If you have not installed the submodules, probably because you ran `git clone <repo link>` instead of the CLI command in step 1, you may run into errors when running `forge build` since it is looking for the dependencies for the project. `git submodule update --init --recursive` can be used if you clone the repo without installing the submodules.

2. Install forge on your machine if you have not already: `forge install`

> NOTE: If you need to download the latest version of foundry, just run `foundryup` 

3. Build the project and make sure everything compiles: `forge build`

## Unit Tests Against Local Mainnet Fork

To run unit tests against a non-persistent local mainnet fork, first make sure you have a `.env` file set up at the root (follow `.env.example` format) and populate the `RPC_URL` variable like so:

`RPC_URL="<insert ETH RPC URL here>"`

Make sure you are using latest version of foundry, so that it auto-sources `.env`, otherwise run (while in the root directory): `source .env`

CLI command: `forge test`

## VSCode

If you are using Juan Blanco's [solidity](https://marketplace.visualstudio.com/items?itemName=JuanBlanco.solidity) extension on VSCode, you can use this settings:

```ts
{
  "solidity.remappings": [
    "forge-std/=lib/forge-std/src/",
    "@openzeppelin=lib/openzeppelin-contracts/",
    "@chainlink=lib/chainlink/",
    "@protocol=src/protocol/",
    "@modules=src/modules/",
    "@external=src/external/",
    "@oracle=src/oracle/"
  ],
  "solidity.compileUsingRemoteVersion": "v0.8.13+commit.abaa5c0e"
}
```

## Hardhat

### Running Locally

Follow the CLI commands outlined below to deploy the vyper contracts on a local blockchain.

First, install dependencies.
```
$ npm install
```

Second, open a new window and start the local blockchain using the below CLI command:
```
$ npx hardhat node
```

Third, open a new window where you will run the following command to deploy the vyper contracts to the local network.

```
$ npx hardhat run --network localhost scripts/hardhat/deployGaugeController.ts
```

### Reasoning for Hardhat

Vyper compatibility with foundry is still in the works, so Hardhat is chosen as a working framework.

Hardhat is only used with vyper contracts and contracts that interact with them. More information can be found on hardhat deployment [here](https://hardhat.org/hardhat-runner/docs/guides/deploying).

```
npx hardhat run --network <your-network> scripts/hardhat/deploy.js
```

### Vyper

Inspiration for the hardhat-vyper setup: https://github.com/de33/hardhat-vyper-starter