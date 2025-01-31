#!/bin/sh
RPC_URL=""
VERIFY_URL=""
PRIVATE_KEY=""
ETHERSCAN_API_KEY=""

export VERSION="1.0.0" # 1.0.0
export ENVIRONMENT="staging" #staging, production


CONTRACTS=("usdplus" "transfer_restrictor" "usdplus_minter" "usdplus_redeemer" "ccip_waypoint")

for i in "${CONTRACTS[@]}"; do
    echo "Deploying $i"
    export CONTRACT=$i
    forge script script/Release.s.sol \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --verify \
    --broadcast \
    -vvv || echo "Failed to deploy $i, continuing..."
done

echo "Deployment process completed."