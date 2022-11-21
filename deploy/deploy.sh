#!/bin/bash

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
   
log_path="broadcast/$CONTRACT_NAME.s.sol/1/run-latest.json"

if [[ -z $SIG ]]
then 
    SIG=0xc0406226
else 
    func_sig=${SIG:2:8}
    log_path="broadcast/$CONTRACT_NAME.s.sol/1/$func_sig-latest.json"
fi

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
        
        contents="$(jq .[$name]="$address" deployments/addresses_last.json)" && echo -E "${contents}" > deployments/addresses_last.json
        
    fi
done


