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
    "@openzeppelin=lib/openzeppelin-contracts/"
  ],
  "solidity.compileUsingRemoteVersion": "v0.8.13+commit.abaa5c0e"
}
```
