#!/bin/sh

cp .env-base-sepolia .env
source .env

forge script script/ccip/CCIPTokenTransfer.s.sol:CCIPTokenTransfer --rpc-url $RPC_URL -vvv --broadcast
