#!/bin/sh

cp .env-kinto-prod .env
source .env

forge script script/kinto/ConfigAll.s.sol:ConfigAll --rpc-url $RPC_URL -vvvv --broadcast --skip-simulation
