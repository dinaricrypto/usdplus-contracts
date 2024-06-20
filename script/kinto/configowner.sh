#!/bin/sh

cp .env-kinto .env
source .env

forge script script/kinto/ConfigAllOwnerUsdPlus.s.sol:ConfigAllOwnerUsdPlus --rpc-url $RPC_URL -vvvv --broadcast --skip-simulation
