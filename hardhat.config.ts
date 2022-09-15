import * as dotenv from 'dotenv';
dotenv.config()

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
};

export default config;
