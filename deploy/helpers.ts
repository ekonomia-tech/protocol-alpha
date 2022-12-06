import {
  SignatureParam,
  DeployParams,
  MasterAddresses,
  Networks,
  CommandParams,
  AddressParams,
} from "./types";
import { exec } from "child_process";
// import addresses from "../addresses_master.json";
import { writeFileSync, readdirSync, lstatSync } from "fs";
import * as networks from "./networks.json";
import { copyFile } from "fs/promises";
import path from "path";

export function getNetworkRPC(network: string): string {
  let n: Networks = networks;
  return n[network];
}

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
  return `forge script scripts/${p.contractName}.s.sol:${p.contractName} --fork-url ${p.forkUrl} --private-key ${p.privateKey} --sig ${p.sig} --broadcast -vvvv`;
}

export async function updateAddresses(p: AddressParams): Promise<void> {
  await copyFile("deployments/addresses_last.example.json", "deployments/addresses_last.json", 0);
  let tempAddresses: { [key: string]: string } = require("../../deployments/addresses_last.json");
  let updated: MasterAddresses = addresses;
  return new Promise<{
    updated: MasterAddresses;
    tempAddresses: { [key: string]: string };
  }>((resolve) => {
    let latestLog: string | undefined = getMostRecentFile(`broadcast/${p.contractName}.s.sol/1/`);
    if (!latestLog) return;
    let json = require(`../../broadcast/${p.contractName}.s.sol/1/${latestLog}`);
    json.transactions.forEach((trx: any) => {
      if (p.contractName == "DeployCurvePool") {
        let { transactionType, address } = trx.additionalContracts[0];
        if (transactionType == "CREATE") {
          updated[p.network].core.CurvePool = address;
          tempAddresses.CurvePool = address;
        }
      } else {
        if (trx.transactionType == "CREATE") {
          let cl = p.contractLabel || trx.contractName;
          if (p.isCore) {
            updated[p.network].core[cl] = trx.contractAddress;
          } else {
            updated[p.network].modules[cl] = trx.contractAddress;
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
