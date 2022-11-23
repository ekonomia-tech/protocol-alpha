import { SignatureParam, DeployParams, MasterAddresses } from "./types";
import {exec} from "child_process";
import * as addresses from "../../addresses_master_ts.json";


export async function generateSignature(params: SignatureParam[], ): Promise<string> {
    let typeString: string = "";
    let valueString: string = "";
    
    if (params.length == 0) {
        return "0xc0406226";
    }

    params.forEach((param: SignatureParam, i: number) => {
        let { type, value } = param;
        typeString += type;
        valueString += value;
        if (i+1 != params.length) {
            typeString += ",";
            valueString += " ";
        }
    })

    let command: string = `cast calldata "run(${typeString})" ${valueString}`;
    return await execute(command);
}

export function checkRequired(addresses: any): boolean {
    if (Object(addresses).entries().length == 0) {
        console.log("------------------------------------------------------------------------------------");
        console.log("Error:");
        console.log("There are contract addresses missing that are needed run this process.");
        console.log("Please run a full deployment on $NETWORK and try to run this process again.");
        console.log("------------------------------------------------------------------------------------");
        return false;
    }
    return true;
}

export async function execute(command: string): Promise<any> {
    return new Promise((resolve) => {
            exec(command, (e, r) => {
            if (e) {
                console.log(e);
                return;
            }
            resolve(r);
        });
    })
}

export function generateForgeCommand(params: DeployParams, sig: string): string {
    let { contractName, forkUrl, privateKey } = params;
    return `forge script scripts/${contractName}.s.sol:${contractName} --fork-url ${forkUrl} --private-key ${privateKey} --sig ${sig} --silent --broadcast`;
}

export function updateAddresses(contractName: string, sig: string, network: string, contractType: string, contractLabel: string | null): void {
    let updated: MasterAddresses = addresses;
    let json = require(`../../broadcast/${contractName}.s.sol/1/${sig}-latest.json`);
    json.transactions.forEach((trx: any) => {
        if (contractName == "CurvePool") {
            let { transactionType, address } = trx.additionalContracts;
            if (transactionType == "CREATE") {
                updated[network].core.CurvePool = address;
            }
        } else {
            if (trx.transactionType == "CREATE") {
                let cl = contractLabel || trx.contractName;
                updated[network].core[cl] = trx.contractAddress; 
            }
        }
    })
    console.log(updated.render.core.PHO);
}