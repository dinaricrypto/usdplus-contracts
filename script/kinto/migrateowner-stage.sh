#!/bin/sh

cp .env-kinto-stage .env
source .env

forge script script/kinto/MigrateOwner.s.sol:MigrateOwner --rpc-url $RPC_URL -vvv --broadcast --skip-simulation --slow
