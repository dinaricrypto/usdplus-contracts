#!/bin/sh

cp .env-local .env
source .env

forge script script/DeployTokenOnly.s.sol:DeployTokenOnly --rpc-url $RPC_URL -vvvv --broadcast --slow
