#!/bin/sh

cp .env-sepolia .env
source .env

forge script script/CCIPTokenTransfer.s.sol:CCIPTokenTransfer --rpc-url $RPC_URL -vvv --broadcast
