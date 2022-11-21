
while getopts n:f:p:m: flag
do
    case "${flag}" in
        n) NETWORK=${OPTARG};;
        f) FORK_URL=${OPTARG};;
        p) PRIVATE_KEY=${OPTARG};;
        m) MODULE_ADDRESS=${OPTARG};;
    esac
done

SIG=$(cast calldata "run(string,address)" $NETWORK $MODULE_ADDRESS)
forge script scripts/UpdateAddModule.s.sol:UpdateAddModule --fork-url $FORK_URL --private-key $PRIVATE_KEY --sig $SIG --silent --broadcast 

MODULE_MANAGER=$(jq ".ModuleManager" deployments/$NETWORK/addresses_latest.json | tr -d '"')

RES=$(cast call --rpc-url $FORK_URL $MODULE_MANAGER "modules(address)((uint256,uint256,uint256,uint256,uint256,uint256))" $MODULE_ADDRESS)

echo "Module info => $RES"

