# protocol-alpha

Alpha version of a DeFi stablecoin protocol

# What is the Protocol?

- We are working on a DeFi stablecoin protocol. The stablecoin is algorithmically / partially backed by collateral.
- We have our own novel ideas around reputation & other aspects of the protocol we are building.

# Developer Notes

To start the project, clone the repo to your local machine using the following CLI command:

1. Clone the repo onto your local machine and install the submodules: `git clone --recursive <repo link>`

   > NOTE: If you have not installed the submodules, probablye because you ran `git clone <repo link>` instead of the CLI command in step 1, you may run into errors when running `forge build` since it is looking for the dependencies for the project. `git submodule update --init --recursive` can be used if you clone the repo without installing the submodules.

2. Install forge on your machine if you do not have it already: `forge install`

> NOTE: If you need to download the latest version of foundry, just run `foundryup`

3. Build the project: `forge build`

## Unit Tests Against Local Mainnet Fork

To run unit tests against a non-persistent local mainnet fork:

CLI command: `forge test --fork-url https://mainnet.infura.io/v3/796ad259dab546fa8d7e081818b0ec31`
