import "@nomiclabs/hardhat-vyper";
import { HardhatUserConfig } from "hardhat/types";

const config: HardhatUserConfig = {
  solidity: "0.8.9",
  vyper: {
    version: "0.3.0",
  },
};

export default config;