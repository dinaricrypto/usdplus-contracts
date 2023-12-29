#!/bin/sh

cp .env-base-goerli .env
source .env

forge script script/CCIPWaypointTransfer.s.sol:CCIPWaypointTransfer --rpc-url $RPC_URL -vvv --broadcast
