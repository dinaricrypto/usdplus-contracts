#!/bin/sh

cp .env-kinto-stage .env
source .env

forge script script/kinto/MintDirect.s.sol:MintDirect --rpc-url $RPC_URL -vvvv --broadcast --skip-simulation
