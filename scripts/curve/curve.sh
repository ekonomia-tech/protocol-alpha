#!/bin/sh

./scripts/curve/deploy.sh;

set -eo pipefail

source ./scripts/curve/vars.sh;
source ./scripts/curve/addresses.sh;

function log() {
    echo "----" >> ./scripts/curve/logs/last_run.log;
    echo "$1" >> ./scripts/curve/logs/last_run.log;
    echo "----" >> ./scripts/curve/logs/last_run.log;
}


echo "";
echo "----------------------------------";
echo "Curve pools deployment and funding";
echo "----------------------------------";

## --------------------------
## Fund owner address with USDC
## --------------------------

log "Fund owner address with USDC";

cast rpc anvil_impersonateAccount $USDC_holder_address >> /dev/null 2>&1;
cast send $USDC_address "transfer(address,uint256)" $owner_address $fifty_m_d6 --from $USDC_holder_address >> ./scripts/curve/logs/last_run.log;

owner_usdc_balance=$(cast call $USDC_address "balanceOf(address)(uint256)" $owner_address);
if [ $owner_usdc_balance == $fifty_m_d6 ]
then
    echo "-- Owner USDC balance -> $owner_usdc_balance ";
else
    echo "Failed to fund owner account";
    exit 0;
fi;



## --------------------------
## Fund FraxBP pool
## --------------------------

log "fund FraxBP pool";

cast send $USDC_address "approve(address,uint256)(bool)" $frax_bp_address $ten_m_d6 --from $owner_address >> ./scripts/curve/logs/last_run.log;
if [ $(cast call $USDC_address "allowance(address,address)(uint256)" $owner_address $frax_bp_address) != $ten_m_d6 ]
then 
    echo "USDC Funds approval failed for FraxBP";
    exit 0;
fi;

cast send $frax_bp_address "add_liquidity(uint256[2],uint256)(uint256)" "[0,$ten_m_d6]" 0 --from $owner_address >> ./scripts/curve/logs/last_run.log;
owner_frax_bp_balance=$(cast call $frax_bp_lp_address "balanceOf(address)(uint256)" $owner_address);

echo "-- Owner FraxBP balance -> $owner_frax_bp_balance";



## --------------------------
## Deploy FRAXBP-EUSD pool
## --------------------------

log "Deploy FRAXBP-EUSD pool";

cast send $curve_factory_address "deploy_metapool(address,string,string,address,uint256,uint256)(address)" $frax_bp_address "FRAXBP-EUSD" "FRAXBPEUSD" $eusd_address 10 4000000 295330021868150247895544788229857886848430702695 --from $owner_address >> ./scripts/curve/logs/last_run.log;

pool_count=$(cast call $curve_factory_address "pool_count()(uint256)");
fraxbp_eusd_address=$(cast call $curve_factory_address "pool_list(uint256)(address)" $(($pool_count-1)));

if [[ $(cast call $fraxbp_eusd_address "name()(string)") == *"FRAXBP-EUSD"* ]]
then 
    echo "-- FRAXBP-EUSD metapool successfully deployed";
else
    echo "Failed to deploy FRAXBP-EUSD metapool";
    exit 0;
fi;



## --------------------------
## Mint EUSD to owner
## --------------------------

log "Mint EUSD to owner"

cast send $USDC_address "approve(address,uint256)(bool)" $fraxbp_eusd_address $ten_m_d6 --from $owner_address >> ./scripts/curve/logs/last_run.log;

if [ $(cast call $USDC_address "allowance(address,address)(uint256)" $owner_address $fraxbp_eusd_address) != $ten_m_d6 ]
then 
    echo "USDC Funds approval failed for FraxBP";
    exit 0;
fi;

cast send $eusd_address "pool_mint(address,uint256)" $owner_address $owner_frax_bp_balance --from $owner_address >> ./scripts/curve/logs/last_run.log;
owner_eusd_balance=$(cast call $eusd_address "balanceOf(address)(uint256)" $owner_address);

echo "-- Owner EUSD Balance -> $owner_eusd_balance";



## --------------------------
## Approve EUSD to FraxBP-EUSD pool
## --------------------------

log "Approve EUSD to FraxBP-EUSD pool"

cast send $eusd_address "approve(address,uint256)(bool)" $fraxbp_eusd_address $owner_eusd_balance --from $owner_address >> ./scripts/curve/logs/last_run.log;

if [ $(cast call $eusd_address "allowance(address,address)(uint256)" $owner_address $fraxbp_eusd_address) != $owner_eusd_balance ]
then 
    echo "EUSD Funds approval failed for FRAXBP-EUSD pool";
    exit 0;
fi;


## --------------------------
## Approve FraxBP_EUSD pull on FraxBp LP
## --------------------------

log "Approve FraxBP_EUSD pull on FraxBp LP";

cast send $frax_bp_lp_address "approve(address,uint256)(bool)" $fraxbp_eusd_address $owner_frax_bp_balance --from $owner_address >> ./scripts/curve/logs/last_run.log;

if [ $(cast call $frax_bp_lp_address "allowance(address,address)(uint256)" $owner_address $fraxbp_eusd_address) != $owner_frax_bp_balance ]
then 
    echo "FraxBP LP Funds approval failed for FRAXBP-EUSD pool";
    exit 0;
fi;

## --------------------------
## Deploy funds into FRAXBP-EUSD pool
## --------------------------

log "Deploy funds into FRAXBP-EUSD pool";

cast send $fraxbp_eusd_address "add_liquidity(uint256[2],uint256)(uint256)" "[$owner_frax_bp_balance,$owner_eusd_balance]" 0 --from $owner_address >> ./scripts/curve/logs/last_run.log;

owner_fraxbp_eusd_balance=$(cast call $fraxbp_eusd_address "balanceOf(address)(uint256)" $owner_address);

echo "-- FraxBP-EUSD owner balance -> $owner_fraxbp_eusd_balance";