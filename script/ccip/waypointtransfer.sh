#!/bin/sh

cp .env-arbitrum .env
source .env

forge script script/ccip/WaypointTransfer.s.sol:WaypointTransfer --rpc-url $RPC_URL -vvv --broadcast
