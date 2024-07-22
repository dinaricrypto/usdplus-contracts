#!/bin/sh

cp .env-kinto-prod .env
source .env

forge script script/kinto/MigrateOwner.s.sol:MigrateOwner --rpc-url $RPC_URL -vvv --broadcast --skip-simulation --slow
