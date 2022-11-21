
while getopts n:f:p:m:c: flag
do
    case "${flag}" in
        n) NETWORK=${OPTARG};;
        f) FORK_URL=${OPTARG};;
        p) PRIVATE_KEY=${OPTARG};;
        m) MODULE_ADDRESS=${OPTARG};;
        c) PHO_CEILING_IN_MIL=${OPTARG};;
    esac
done

CEIL=$(bc <<< 200*1000000*10^18)

SIG=$(cast calldata "run(string,address,uint256)" $NETWORK $MODULE_ADDRESS $CEIL)
forge script scripts/UpdateModulePHOCeiling.s.sol:UpdateModulePHOCeiling --fork-url $FORK_URL --private-key $PRIVATE_KEY --sig $SIG --silent --broadcast 

MODULE_MANAGER=$(jq ".ModuleManager" deployments/$NETWORK/addresses_latest.json | tr -d '"')

RES=$(cast call --rpc-url $FORK_URL $MODULE_MANAGER "modules(address)((uint256,uint256,uint256,uint256,uint256,uint256))" $MODULE_ADDRESS)

echo "Module info => $RES"

