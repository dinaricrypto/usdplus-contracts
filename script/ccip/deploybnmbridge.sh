#!/bin/sh

cp .env-sepolia .env
source .env

forge script script/ccip/DeployCCIPWaypointBnM.s.sol:DeployCCIPWaypointBnM --rpc-url $RPC_URL -vvv --broadcast --verify

cp .env-arbitrum-sepolia .env
source .env

forge script script/ccip/DeployCCIPWaypointBnM.s.sol:DeployCCIPWaypointBnM --rpc-url $RPC_URL -vvv --broadcast --verify
