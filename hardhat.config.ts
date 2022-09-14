import { HardhatUserConfig } from "hardhat/types";

import "@nomiclabs/hardhat-vyper";
import "@nomiclabs/hardhat-ethers";

// path configuration:
// https://hardhat.org/hardhat-runner/docs/config#path-configuration

const config: HardhatUserConfig = {
  solidity: "0.8.9",
  vyper: {
    version: "0.3.2",
  },
  paths: {
    sources: "./src/hardhat",
  },
  networks: {
    mainnet: {
      accounts: { mnemonic: process.env.MNEMONIC },
    },
    goerlii: {
      accounts: { mnemonic: process.env.MNEMONIC },
    },
  },
};

export default config;
