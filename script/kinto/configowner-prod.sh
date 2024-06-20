#!/bin/sh

cp .env-kinto-prod .env
source .env

forge script script/kinto/ConfigAllOwnerUsdPlus.s.sol:ConfigAllOwnerUsdPlus --rpc-url $RPC_URL -vvvv --broadcast --skip-simulation
