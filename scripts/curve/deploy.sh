#!/bin/sh

source ./scripts/curve/vars.sh;
source ./scripts/curve/vars.sh;
source .env;

if test -f "$log_path"; then
    rm -rf $log_path;
fi


function kill_anvil() {
    pids=$(lsof -t -i:8545);
    for pid in $pids
    do
        kill -9 $pid
    done
}

function log() {
    echo "----" >> $log_path;
    echo "$1" >> $log_path;
    echo "----" >> $log_path;
}

echo "";
echo "Spinning up anvil (~10s)...";

kill_anvil

anvil --fork-url $PROVIDER_KEY > /dev/null 2>&1 &

sleep 10

echo "Anvil initialized successfully";
echo "";
echo "----------------------------------";
echo "Initiating contracts deployment...";
echo "----------------------------------";



## --------------------------
## Deploy Price Oracle
## --------------------------

dummy_oracle_address=$(forge create \
    --rpc-url $RPC_URL \
    --private-key $owner_pk "$dummy_oracle_contract:DummyOracle" \
    | grep "Deployed to:" \
    | sed "s/Deployed to: //g");

if [ $(cast call $dummy_oracle_address "usdc_usd_price()(uint256)") == $usdc_usd_price ]
then
    echo "-- Dummy Oracle successfully deployed";
else
    echo "Failed to deploy price oracle";
    exit 0;
fi;



## --------------------------
## Deploy EUSD contract
## --------------------------

eusd_address=$(forge create \
    --rpc-url $RPC_URL \
    --private-key $owner_pk "$eusd_contract:EUSD" \
    --constructor-args "Eusd" "EUSD" $owner_address $timelock_address \
    | grep "Deployed to:" \
    | sed "s/Deployed to: //g");

if [ $(cast call $eusd_address "SYMBOL()(string)") == "EUSD" ]
then
    echo "-- EUSD successfully deployed";
else
    echo "Failed to deploy EUSD";
    exit 0;
fi;



## --------------------------
## Deploy PIDController contract
## --------------------------

pidcontroller_address=$(forge create \
    --rpc-url $RPC_URL \
    --private-key $owner_pk "$pidcontroller_contract:PIDController" \
    --constructor-args $eusd_address $owner_address $timelock_address $dummy_oracle_address \
    | grep "Deployed to:" \
    | sed "s/Deployed to: //g");

if [ $(cast call $pidcontroller_address "refresh_cooldown()(uint256)") == 3600 ]
then
    echo "-- PIDController successfully deployed";
else
    echo "Failed to deploy PIDController";
    exit 0;
fi;



## --------------------------
## Deploy Share contract
## --------------------------

share_address=$(forge create \
    --rpc-url $RPC_URL \
    --private-key $owner_pk "$share_contract:Share" \
    --constructor-args "Share" "SHARE" $dummy_oracle_address $timelock_address \
    | grep "Deployed to:" \
    | sed "s/Deployed to: //g");

if [ $(cast call $share_address "decimals()(uint256)") == 18 ]
then
    echo "-- Share successfully deployed";
else
    echo "Failed to deploy Share";
    exit 0;
fi;

echo "";
echo "-----------------------";
echo "Set contract variables:"
echo "-----------------------";


## --------------------------
## PIDController - set minting fee
## --------------------------
cast send $pidcontroller_address "setMintingFee(uint256)" $minting_fee --from $owner_address >> /dev/null 2>&1;
echo "-- PIDController - Minting fee set -> $minting_fee";


## --------------------------
## PIDController - set redemption fee
## --------------------------

cast send $pidcontroller_address "setRedemptionFee(uint256)" $redemption_fee --from $owner_address >> /dev/null 2>&1;
echo "-- PIDController - Redemption fee set -> $redemption_fee";


## --------------------------
## PIDController - Set controller
## --------------------------
cast send $pidcontroller_address "setController(address)" $controller_address --from $owner_address >> /dev/null 2>&1;
echo "-- PIDController - Controller address set -> $controller_address";


## --------------------------
## Share set EUSD Address
## --------------------------

cast send $share_address "setEUSDAddress(address)" $eusd_address --from $owner_address >> /dev/null 2>&1;
echo "-- Share - EUSD Address set -> $eusd_address";


## --------------------------
## EUSD Set controller
## --------------------------

cast send $eusd_address "setController(address)" $controller_address --from $owner_address >> /dev/null 2>&1;
echo "-- EUSD - Controller address set -> $controller_address";


## --------------------------
## Add owner as a pool to be able to mint EUSD
## --------------------------
cast send $eusd_address "addPool(address)" $owner_address --from $owner_address >> /dev/null 2>&1;
echo "-- EUSD - Owner granted minting/burning privileges";


rm -rf ./scripts/curve/addresses.sh;

echo "dummy_oracle_address=\"$dummy_oracle_address\";" >> ./scripts/curve/addresses.sh;
echo "eusd_address=\"$eusd_address\";" >> ./scripts/curve/addresses.sh;
echo "pidcontroller_address=\"$pidcontroller_address\";" >> ./scripts/curve/addresses.sh;
echo "share_address=\"$share_address\";" >> ./scripts/curve/addresses.sh;

