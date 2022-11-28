export interface SignatureParam {
    type: string;
    value: string | number;
}

export interface DeployParams {
    name: string;
    description: string;
    deploy: boolean;
    contractName: string;
    sigParams: SignatureParam[];
    isCore: boolean;
    contractLabel: string | null;
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

export interface Networks {
    [key: string]: string
}

export interface CommandParams {
    contractName: string;
    forkUrl: string;
    privateKey: string;
    sig: string;
}

export interface AddressParams {
    contractName: string;
    truncSig: string;
    network: string;
    isCore: boolean;
    contractLabel: string | null;
}