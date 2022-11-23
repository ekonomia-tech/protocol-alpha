#!/bin/bash
source "deploy/shared.sh"

while getopts n:f:p: flag
do
    case "${flag}" in
        n) NETWORK=${OPTARG};;
        f) FORK_URL=${OPTARG};;
        p) PRIVATE_KEY=${OPTARG};;
    esac
done

# $logs_dir is returning from create_log_folder function.
create_log_folder $NETWORK

cp deployments/.addresses_last.example.json deployments/addresses_last.json

# Deploy Protocol
DEPLOY_SIG=$(cast calldata "run(address)" 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266)
deploy/deploy.sh -n $NETWORK -f $FORK_URL -c "DeployProtocol" -p $PRIVATE_KEY -s $DEPLOY_SIG -C 1;

# Deploy Curve pool
deploy/deploy.sh -n $NETWORK -f $FORK_URL -c "DeployCurvePool" -p $PRIVATE_KEY -l CurvePool -C 1;

# Deploy Price Controller
PRICE_CONTROLLER_SIG=$(cast calldata "run(uint256,uint256,uint256,uint256)" 604800 10000 50000 99000)
deploy/deploy.sh -n $NETWORK -f $FORK_URL -c "DeployPriceController" -p $PRIVATE_KEY -l PriceController -s $PRICE_CONTROLLER_SIG;

# Deploy USDC stablecoin module
USDC_SIG=$(cast calldata "run(address)" 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48)
deploy/deploy.sh -n $NETWORK -f $FORK_URL -c "DeployStablecoinDepositModule" -p $PRIVATE_KEY -l StablecoinDepositModuleUSDC -s $USDC_SIG;

# Deploy FRAX stablecoin module
FRAX_SIG=$(cast calldata "run(address)" 0x853d955aCEf822Db058eb8505911ED77F175b99e)
deploy/deploy.sh -n $NETWORK -f $FORK_URL -c "DeployStablecoinDepositModule" -p $PRIVATE_KEY -l StablecoinDepositModuleFRAX -s $FRAX_SIG;

# Deploy LUSD stablecoin module
LUSD_SIG=$(cast calldata "run(address)" 0x5f98805A4E8be255a32880FDeC7F6728C6568bA0)
deploy/deploy.sh -n $NETWORK -f $FORK_URL -c "DeployStablecoinDepositModule" -p $PRIVATE_KEY -l StablecoinDepositModuleLUSD -s $LUSD_SIG;

# Deploy Maple USDC Module
USDC_SIG=$(cast calldata "run(address)" 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48)
deploy/deploy.sh -n $NETWORK -f $FORK_URL -c "DeployMapleDepositModule" -p $PRIVATE_KEY -l MapleDepositModuleUSDC -s $USDC_SIG

# Deploy ZCB USDC module
ZCB_USDC_SIG=$(cast calldata "run(address,string,string,uint256,uint256,uint256)" 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 "Test USDC Bond" "USDC-TEST" 1000 86400 86400000)
deploy/deploy.sh -n $NETWORK -f $FORK_URL -c "DeployZCBModule" -p $PRIVATE_KEY -l ZCBModuleUSDC -s $ZCB_USDC_SIG

cp deployments/addresses_last.json $logs_dir/addresses.json
cp deployments/addresses_last.json $logs_dir/../addresses_latest.json
rm deployments/addresses_last.json

