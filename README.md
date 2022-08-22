# protocol-alpha

Alpha version of a DeFi stablecoin protocol

# What is the Protocol?

- We are working on a DeFi stablecoin protocol. The stablecoin is algorithmically / partially backed by collateral.
- We have our own novel ideas around reputation & other aspects of the protocol we are building.

# Developer Notes

To start the project, clone the repo to your local machine using the following CLI commands:

1. Clone the repo onto your local machine and install the submodules: `git clone --recursive <repo link>`

   > NOTE: If you have not installed the submodules, probably because you ran `git clone <repo link>` instead of the CLI command in step 1, you may run into errors when running `forge build` since it is looking for the dependencies for the project. `git submodule update --init --recursive` can be used if you clone the repo without installing the submodules.

2. The repo is utilizing the `Run on save` extension to auto-format all code written on save.
To install the extension, either manually install it through VSCode or install it once VSCode prompts it when opening the project.

3. Install forge on your machine if you have not already: `forge install`

> NOTE: If you need to download the latest version of foundry, just run `foundryup`
4. Build the project and make sure everything compiles: `forge build`

## Unit Tests Against Local Mainnet Fork

To run unit tests against a non-persistent local mainnet fork, first make sure you have a `.env` file set up at the root (follow `.env.example` format) and populate the `PROVIDER_KEY` variable like so:

`PROVIDER_KEY="<INSERT_PROVIDER_API_KEY_HERE>"`

Then run (while in the root directory): `source .env`
> NOTE: the below CLI command is setup with infura as the provider, feel free to use whatever provider you would like, but make the appropriate changes to the CLI command.


CLI command: `forge test --fork-url https://mainnet.infura.io/v3/$PROVIDER_KEY`

