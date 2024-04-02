#!/bin/sh

cp .env-arbitrum-sepolia .env
source .env

forge script script/ccip/DeployCCIPWaypoint.s.sol:DeployCCIPWaypoint --rpc-url $RPC_URL -vvv --broadcast --verify
