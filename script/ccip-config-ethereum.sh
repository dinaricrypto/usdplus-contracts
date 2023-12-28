#!/bin/sh

cp .env-ethereum .env
source .env

forge script script/CCIPWaypointConfig.s.sol:CCIPWaypointConfig --rpc-url $RPC_URL -vvv --broadcast
