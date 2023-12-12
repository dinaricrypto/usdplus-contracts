#!/bin/sh

cp .env-base-goerli .env
source .env

forge script script/CCIPBridgeTransfer.s.sol:CCIPBridgeTransfer --rpc-url $RPC_URL -vvv --broadcast
