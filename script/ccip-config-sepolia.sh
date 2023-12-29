#!/bin/sh

cp .env-sepolia .env
source .env

forge script script/CCIPWaypointConfig.s.sol:CCIPWaypointConfig --rpc-url $RPC_URL -vvv --broadcast
