#!/bin/sh

cp .env-arbitrum-sepolia .env
source .env

forge script script/ccip/CCIPWaypointConfig.s.sol:CCIPWaypointConfig --rpc-url $RPC_URL -vvv --broadcast
