#!/bin/sh

cp .env-sepolia .env
source .env

forge script script/DeployCCIPBridge.s.sol:DeployCCIPBridge --rpc-url $RPC_URL -vvv --broadcast --verify
