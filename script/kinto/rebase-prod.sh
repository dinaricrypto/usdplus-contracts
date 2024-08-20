#!/bin/sh

cp .env-kinto-prod .env
source .env

forge script script/kinto/RebaseAdd.s.sol:RebaseAdd --rpc-url $RPC_URL -vvvv --broadcast --skip-simulation
