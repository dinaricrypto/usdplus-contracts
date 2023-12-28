#!/bin/sh

cp .env-ethereum .env
source .env

forge script script/DeployCCIPWaypoint.s.sol:DeployCCIPWaypoint --rpc-url $RPC_URL -vvv --broadcast --verify
