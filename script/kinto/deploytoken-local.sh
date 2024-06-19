#!/bin/sh

cp .env-local .env
source .env

forge script script/kinto/DeployTokenOnlyKinto.s.sol:DeployTokenOnlyKinto --rpc-url $RPC_URL -vvvv --broadcast --slow
