#!/bin/sh

cp .env-base-goerli .env
source .env

forge script script/CCIPTokenTransfer.s.sol:CCIPTokenTransfer --rpc-url $RPC_URL -vvv --broadcast
