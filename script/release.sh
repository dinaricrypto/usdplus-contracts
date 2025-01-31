#!/bin/sh
RPC_URL=""
VERIFY_URL=""
PRIVATE_KEY=""
ETHERSCAN_API_KEY=""

export VERSION="" # 1.0.0
export CONTRACT="" # transfer_restrictor
export ENVIRONMENT="" #staging, production
export DEPLOYED_VERSION=""

forge script script/Release.s.sol \
   --rpc-url $RPC_URL \
   --etherscan-api-key $ETHERSCAN_API_KEY \
   --private-key $PRIVATE_KEY \
    --verify \
   --broadcast \
   -vvv