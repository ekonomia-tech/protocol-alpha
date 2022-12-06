#!/usr/bin/env ts-node
import * as dotenv from "dotenv";
import yargs from "yargs";

import { protocolCommand } from "./commands";
import { cliOpts } from "./defaults";

dotenv.config();

yargs
  .parserConfiguration({
    "short-option-groups": true,
    "camel-case-expansion": true,
    "dot-notation": true,
    "parse-numbers": false,
    "parse-positional-numbers": false,
    "boolean-negation": true,
  })
  .env(true)
  .option("m", cliOpts.mnemonic)
  .option("p", cliOpts.providerUrl)
  .option("n", cliOpts.accountNumber)
  .command(protocolCommand)
  .demandCommand(1, "Choose a command from the above list")
  .help().argv;
