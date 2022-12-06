
import { DeployParams} from "./types";
import { deployData } from "./deployParams.json";
import { execute, generateForgeCommand, generateSignature, updateAddresses, getNetworkRPC } from "./helpers";
// require('dotenv').config()

export async function deployContracts(network: string, privateKey: string): Promise<void> {
    let dArray: DeployParams[] = deployData.filter((d: DeployParams) => d.deploy);
    for(const data of dArray) {
        let sig = await generateSignature(data.sigParams);
        let forgeCommand = generateForgeCommand({
            contractName: data.contractName,
            forkUrl: getNetworkRPC(network),
            privateKey: privateKey,
            sig
        });
        await execute(forgeCommand);
        await updateAddresses({
            contractName: data.contractName, 
            truncSig: sig.substring(2,10), 
            network, 
            isCore: data.isCore, 
            contractLabel: data.contractLabel
        });
        console.log(`Finished deploying ${data.name}`)
    }
    await execute("npm run prettier:addresses");
}