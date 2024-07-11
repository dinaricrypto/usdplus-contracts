#!/bin/sh

cp .env-kinto-prod .env
source .env

forge script script/kinto/FillRedeem.s.sol:FillRedeem --rpc-url $RPC_URL -vvvv --broadcast --skip-simulation
