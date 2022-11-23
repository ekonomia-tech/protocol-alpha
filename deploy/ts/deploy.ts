
import {  DeployParams} from "./types";
import * as deployData from "./deployParams.json";
import { execute, generateForgeCommand, generateSignature, updateAddresses } from "./helpers";
import * as networks from "./networks.json";
require('dotenv').config()

async function deployProtocol(network: string, forkUrl: string, privateKey: string): Promise<void> {
    let params: DeployParams = {
        network,
        ...deployData.protocol,
        privateKey,
        forkUrl,
    }
    let sig = await generateSignature(deployData.protocol.sigParams);
    let forgeCommand = generateForgeCommand(params, sig);
    execute(forgeCommand);

    updateAddresses(params.contractName, sig.substring(2,10), network , "core", null);
}

deployProtocol("render", networks.render, process.env.PRIVATE_KEY || "");