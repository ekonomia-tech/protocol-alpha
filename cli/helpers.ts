import { logger } from "ethers";
import { getNetworkRPC } from "../deploy/helpers";
import { DeployParams } from "../deploy/types";
import { deployData } from "../deploy/deployParams.json";

export const getModuleName = (network: string, moduleId: string) : string => {
    try {
        let moduleName = "";
        let latest = require(`../deployments/${network}/addresses_latest.json`);
        Object.entries(latest).forEach(entry => {
            const [name, address] = entry;
            if(address == moduleId){
                moduleName = name;
            }
        })
        return moduleName;
    } catch (err) {
        logger.info("Module address missing or does not exist in last deployment");
        return "";
    }
}

export const getModuleData = (moduleName: string) : DeployParams | null => {
    for (let i = 0; i < deployData.length; i++) {
        if (deployData[i].contractLabel == moduleName) {
            return deployData[i];
        }
    }
    return null;
}

export const verifyModule = (network: string, moduleId: string) : boolean => {
    try {
        let exists = false;
        let addresses = require(`../addresses.json`);
        let modules = addresses[network].modules;
        Object.values(modules).forEach(address => {
            if(address == moduleId){
                exists = true;
            }
        })
        return exists;
    } catch (err) {
        logger.info("Module address missing or does not exist in last deployment");
        return false;
    }
}

export const verifyNetwork = (target: string): boolean => {
    if (!target) {
        logger.info("First parameter should be the network name");
        return false;
    } else if (!getNetworkRPC(target)) {
        logger.info(`Network ${target} does not have a RPC_URK record in the .env file`)
        return false;
    }
    return true;
  }