#!/bin/sh

./scripts/curve/deploy.sh;

set -eo pipefail;

source ./scripts/curve/vars.sh;
source ./scripts/curve/addresses.sh;

function log() {
    echo "----" >> $log_path;
    echo "$1" >> $log_path;
    echo "----" >> $log_path;
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
cast send $USDC_address "transfer(address,uint256)" $owner_address $fifty_m_d6 --from $USDC_holder_address >> $log_path;

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

cast send $USDC_address "approve(address,uint256)(bool)" $frax_bp_address $ten_m_d6 --from $owner_address >> $log_path;
if [ $(cast call $USDC_address "allowance(address,address)(uint256)" $owner_address $frax_bp_address) != $ten_m_d6 ]
then 
    echo "USDC Funds approval failed for FraxBP";
    exit 0;
fi;

cast send $frax_bp_address "add_liquidity(uint256[2],uint256)(uint256)" "[0,$ten_m_d6]" 0 --from $owner_address >> $log_path;
owner_frax_bp_balance=$(cast call $frax_bp_lp_address "balanceOf(address)(uint256)" $owner_address);

echo "-- Owner FraxBP balance -> $owner_frax_bp_balance";



## --------------------------
## Deploy FRAXBP-PHO pool
## --------------------------

log "Deploy FRAXBP-PHO pool";

cast send $curve_factory_address "deploy_metapool(address,string,string,address,uint256,uint256)(address)" $frax_bp_address "FRAXBP-PHO" "FRAXBPPHO" $pho_address 10 4000000 295330021868150247895544788229857886848430702695 --from $owner_address >> $log_path;

pool_count=$(cast call $curve_factory_address "pool_count()(uint256)");
fraxbp_pho_address=$(cast call $curve_factory_address "pool_list(uint256)(address)" $(($pool_count-1)));

if [[ $(cast call $fraxbp_pho_address "name()(string)") == *"FRAXBP-PHO"* ]]
then 
    echo "-- FRAXBP-PHO metapool successfully deployed";
else
    echo "Failed to deploy FRAXBP-PHO metapool";
    exit 0;
fi;



## --------------------------
## Mint PHO to owner
## --------------------------

log "Mint PHO to owner"

cast send $USDC_address "approve(address,uint256)(bool)" $fraxbp_pho_address $ten_m_d6 --from $owner_address >> $log_path;

if [ $(cast call $USDC_address "allowance(address,address)(uint256)" $owner_address $fraxbp_pho_address) != $ten_m_d6 ]
then 
    echo "USDC Funds approval failed for FraxBP";
    exit 0;
fi;

cast send $pho_address "pool_mint(address,uint256)" $owner_address $owner_frax_bp_balance --from $owner_address >> $log_path;
owner_pho_balance=$(cast call $pho_address "balanceOf(address)(uint256)" $owner_address);

echo "-- Owner PHO Balance -> $owner_pho_balance";



## --------------------------
## Approve PHO to FraxBP-PHO pool
## --------------------------

log "Approve PHO to FraxBP-PHO pool"

cast send $pho_address "approve(address,uint256)(bool)" $fraxbp_pho_address $owner_pho_balance --from $owner_address >> $log_path;

if [ $(cast call $pho_address "allowance(address,address)(uint256)" $owner_address $fraxbp_pho_address) != $owner_pho_balance ]
then 
    echo "PHO Funds approval failed for FRAXBP-PHO pool";
    exit 0;
fi;


## --------------------------
## Approve FraxBP_PHO pull on FraxBp LP
## --------------------------

log "Approve FraxBP_PHO pull on FraxBp LP";

cast send $frax_bp_lp_address "approve(address,uint256)(bool)" $fraxbp_pho_address $owner_frax_bp_balance --from $owner_address >> $log_path;

if [ $(cast call $frax_bp_lp_address "allowance(address,address)(uint256)" $owner_address $fraxbp_pho_address) != $owner_frax_bp_balance ]
then 
    echo "FraxBP LP Funds approval failed for FRAXBP-PHO pool";
    exit 0;
fi;

## --------------------------
## Deploy funds into FRAXBP-PHO pool
## --------------------------

log "Deploy funds into FRAXBP-PHO pool";

cast send $fraxbp_pho_address "add_liquidity(uint256[2],uint256)(uint256)" "[$owner_frax_bp_balance,$owner_pho_balance]" 0 --from $owner_address >> $log_path;

owner_fraxbp_pho_balance=$(cast call $fraxbp_pho_address "balanceOf(address)(uint256)" $owner_address);

echo "-- FraxBP-PHO owner balance -> $owner_fraxbp_pho_balance";