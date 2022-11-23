export interface SignatureParam {
    type: string;
    value: string;
}

export interface DeployParams {
    network: string;
    forkUrl: string; 
    contractName: string; 
    privateKey: string;
    sigParams: SignatureParam[]
}

export interface AddressLogData {
    name: string;
    sig: string;
}

export interface MasterAddresses {
    [key: string]: NetworkContracts;
}

export interface NetworkContracts {
    core: {
        [key: string]: string
    },
    modules: {
        [key: string]: string
    }
}