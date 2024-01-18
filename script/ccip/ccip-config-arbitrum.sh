#!/bin/sh

cp .env-arbitrum .env
source .env

forge script script/CCIPWaypointConfig.s.sol:CCIPWaypointConfig --rpc-url $RPC_URL -vvv --broadcast
