import { exec } from "child_process";
import { copyFile } from "fs/promises";
import { writeFileSync, readdirSync, lstatSync, existsSync, mkdirSync } from "fs";
import path from "path";
import yargs, { Argv } from "yargs";
import { logger } from "../logging";
import { loadEnv } from "../env";
import {
  DeployParams,
  SignatureParam,
  MasterAddresses,
  CommandParams,
  AddressParams,
  CLIEnvironment,
  CLIArgs,
} from "../types";
import addresses from "../../addresses.json";
import { deployData } from "../deployParams.json";
require("dotenv").config();

const buildHelp = () => {
  let help = "$0 protocol deploy [target]\n Photon protocol deployment";
  return help;
};

export const deploy = async (cli: CLIEnvironment, cliArgs: CLIArgs): Promise<void> => {
  const { c: networkId } = cliArgs;
  const privateKey = cli.wallet.privateKey;
  try {
    let dArray: DeployParams[] = deployData.filter((d: DeployParams) => d.deploy);
    for (const data of dArray) {
      let sig = await generateSignature(data.sigParams);
      let forgeCommand = generateForgeCommand({
        contractName: data.contractName,
        forkUrl: cli.providerUrl,
        privateKey: privateKey,
        sig,
        networkId,
      });
      await execute(forgeCommand);
      await updateAddresses({
        contractName: data.contractName,
        truncSig: sig.substring(2, 10),
        networkId,
        isCore: data.isCore,
        contractLabel: data.contractLabel,
      });
      console.log(`Finished deploying ${data.name}`);
    }
    await execute("npm run prettier:addresses");
  } catch (err) {
    logger.info(err);
    return;
  }
};

export async function generateSignature(params: SignatureParam[]): Promise<string> {
  let typeString: string = "";
  let valueString: string = "";

  if (params.length == 0) {
    return "0xc0406226";
  }

  params.forEach((param: SignatureParam, i: number) => {
    let { type, value } = param;
    typeString += type;
    valueString += type == "string" ? `"${value}"` : value;
    if (i + 1 != params.length) {
      typeString += ",";
      valueString += " ";
    }
  });

  let command: string = `cast calldata "run(${typeString})" ${valueString}`;
  return await execute(command);
}

export async function execute(command: string): Promise<any> {
  return new Promise((resolve) => {
    exec(command, (e, r) => {
      if (e) {
        console.log(e);
        return;
      }
      let res: string = r.replace(/^\s+|\s+$/g, "");
      resolve(res);
    });
  });
}

export function generateForgeCommand(p: CommandParams): string {
  return `forge script scripts/${p.contractName}.s.sol:${p.contractName} --fork-url ${p.forkUrl} --private-key ${p.privateKey} --sig ${p.sig} --chain-id ${p.networkId} --broadcast -vvvv`;
}

export async function updateAddresses(p: AddressParams): Promise<void> {
  await copyFile("deployments/addresses_last.example.json", "deployments/addresses_last.json", 0);
  let tempAddresses: { [key: string]: string } = require("../../deployments/addresses_last.json");
  let updated: MasterAddresses = prepareAddressesJson(addresses, p.networkId);
  return new Promise<{
    updated: MasterAddresses;
    tempAddresses: { [key: string]: string };
  }>((resolve) => {
    let latestLog: string | undefined = getMostRecentFile(
      `broadcast/${p.contractName}.s.sol/${p.networkId}/`,
    );
    if (!latestLog) return;
    let json = require(`../../broadcast/${p.contractName}.s.sol/${p.networkId}/${latestLog}`);
    json.transactions.forEach((trx: any) => {
      if (p.contractName == "DeployCurvePool") {
        let { transactionType, address } = trx.additionalContracts[0];
        if (transactionType == "CREATE") {
          updated[p.networkId].core.CurvePool = address;
          tempAddresses.CurvePool = address;
        }
      } else {
        if (trx.transactionType == "CREATE") {
          let cl = p.contractLabel || trx.contractName;
          if (p.isCore) {
            updated[p.networkId].core[cl] = trx.contractAddress;
          } else {
            updated[p.networkId].modules[cl] = trx.contractAddress;
          }
          tempAddresses[cl] = trx.contractAddress;
        }
      }
    });
    resolve({ updated, tempAddresses });
  }).then((res) => {
    let { updated, tempAddresses } = res;
    writeFileSync("addresses.json", JSON.stringify(updated), { flag: "w+" });
    writeFileSync("deployments/addresses_last.json", JSON.stringify(tempAddresses), { flag: "w+" });
    if (!existsSync(`deployments/${p.networkId}`)) {
      mkdirSync(`deployments/${p.networkId}`);
    }
    writeFileSync(
      `deployments/${p.networkId}/addresses_latest.json`,
      JSON.stringify(tempAddresses),
      { flag: "w+" },
    );
  });
}

function getMostRecentFile(dir: string): string | undefined {
  const files = orderRecentFiles(dir);
  return files.length ? files[0].file : undefined;
}

function orderRecentFiles(dir: string): { file: string; mtime: Date }[] {
  return readdirSync(dir)
    .filter((file) => lstatSync(path.join(dir, file)).isFile())
    .map((file) => ({ file, mtime: lstatSync(path.join(dir, file)).mtime }))
    .sort((a, b) => b.mtime.getTime() - a.mtime.getTime());
}

function prepareAddressesJson(json: MasterAddresses, networkId: number): MasterAddresses {
  if (typeof json[networkId] == "undefined") {
    json[networkId] = {
      core: {},
      modules: {},
    };
  }
  return json;
}

export const deployCommand = {
  command: "deploy",
  describe: "deploy contracts from deployParams.json",
  builder: (yargs: Argv): yargs.Argv => {
    return yargs.usage(buildHelp());
  },
  handler: async (argv: CLIArgs): Promise<void> => {
    return deploy(await loadEnv(argv), argv);
  },
};
