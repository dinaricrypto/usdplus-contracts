#!/bin/sh

cp .env-sepolia .env
source .env

forge script script/CCIPWaypointTransfer.s.sol:CCIPWaypointTransfer --rpc-url $RPC_URL -vvv --broadcast
