#!/bin/sh

cp .env-kinto-prod .env
source .env

forge script script/kinto/SendTokens.s.sol:SendTokens --rpc-url $RPC_URL -vvvv --broadcast --skip-simulation
