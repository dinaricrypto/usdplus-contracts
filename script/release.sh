#!/bin/sh
RPC_URL="https://sepolia.infura.io/v3/0a7b42115f6a48c0b2aa5be4aacfd789"
VERIFY_URL="https://sepolia.infura.io/v3/0a7b42115f6a48c0b2aa5be4aacfd789"
PRIVATE_KEY="0xd518574e456daf683bdfd4f85666b3a4de3eac9a014e675347a556fc365c9557"
ETHERSCAN_API_KEY="6W3SFV585FASFJDXG47MSSR4H97AT54TK9"

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