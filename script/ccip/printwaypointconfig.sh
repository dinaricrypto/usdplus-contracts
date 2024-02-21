#!/bin/sh

cp .env-arbitrum .env
source .env

forge script script/ccip/PrintWaypointConfig.s.sol:PrintWaypointConfig --rpc-url $RPC_URL -vvv

cp .env-ethereum .env
source .env

forge script script/ccip/PrintWaypointConfig.s.sol:PrintWaypointConfig --rpc-url $RPC_URL -vvv
