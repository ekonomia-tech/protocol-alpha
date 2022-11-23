#!/bin/bash

source "deploy/shared.sh"

while getopts n:f:c:p:l:s:A:C:P: flag
do
    case "${flag}" in
        n) NETWORK=${OPTARG};;
        f) FORK_URL=${OPTARG};;
        c) CONTRACT_NAME=${OPTARG};;
        p) PRIVATE_KEY=${OPTARG};;
        l) CONTRACT_LABEL=${OPTARG};;
        s) SIG=${OPTARG};;
        C) IS_CORE=${OPTARG:-0};;

    esac
done

addresses_last_json="deployments/addresses_last.json"
if [[ ! -f $addresses_last_json ]]
then
    if [[ ! -f "deployments/$NETWORK/addresses_latest.json" ]]
    then
        echo "------------------------------------------------------------------------------------"
        echo "Error:"
        echo "There are contract addresses missing that are needed run this process."
        echo "Please run a full deployment on $NETWORK and try to run this process again."
        echo "------------------------------------------------------------------------------------"
        exit 0
    fi

    cp "deployments/$NETWORK/addresses_latest.json" $addresses_last_json
    SINGLE_DEPLOYMENT=1
fi

if [[ -z $SIG ]]
then 
    SIG=0xc0406226
fi

func_sig=${SIG:2:8}
log_path="broadcast/$CONTRACT_NAME.s.sol/1/$func_sig-latest.json"

forge script scripts/$CONTRACT_NAME.s.sol:$CONTRACT_NAME --fork-url $FORK_URL --private-key $PRIVATE_KEY --sig $SIG --silent --broadcast 

transactionLength=$(jq ".transactions | length" $log_path)
for ((i=0; i<$transactionLength; i++)) 
do
    action=$(jq ".transactions[$i] | .transactionType" $log_path)
    if [[ $action=="CREATE" ]] 
    then
            name=$(jq ".transactions[$i] | .contractName" $log_path)
        if [[ ! -z $CONTRACT_LABEL ]]
        then
            name="\"$CONTRACT_LABEL\""
        fi
        
        address=$(jq ".transactions[$i] | .contractAddress" $log_path)

        if [[ $CONTRACT_LABEL == "CurvePool" ]]
        then
            address=$(jq ".transactions[$i] | .additionalContracts[0].address" $log_path)
        fi
        
        contents="$(jq .[$name]="$address" $addresses_last_json)" && echo -E "${contents}" > deployments/addresses_last.json

        if [[ $IS_CORE == 1 ]] 
        then
            contents="$(jq .$NETWORK.core[$name]="$address" addresses_master.json)" && echo -E "${contents}" > addresses_master.json
        else
            contents="$(jq .$NETWORK.modules[$name]="$address" addresses_master.json)" && echo -E "${contents}" > addresses_master.json
        fi
        
        
    fi
done



if [[ $SINGLE_DEPLOYMENT == 1 ]]
then
    create_log_folder $NETWORK
    cp $addresses_last_json "$logs_dir/addresses.json"
    cp $addresses_last_json "$logs_dir/../addresses_latest.json"
    rm $addresses_last_json
fi