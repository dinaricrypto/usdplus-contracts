#!/bin/sh

cp .env-base-goerli .env
source .env

forge script script/DeployCCIPBridge.s.sol:DeployCCIPBridge --rpc-url $RPC_URL -vvv --broadcast --verify
