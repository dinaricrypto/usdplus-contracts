#!/bin/sh

cp .env-local .env
source .env

forge script script/kinto/DeployAllCreate2.s.sol:DeployAllCreate2 --rpc-url $RPC_URL -vvvv --broadcast --slow
