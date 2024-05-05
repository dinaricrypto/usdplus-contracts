#!/bin/sh

cp .env-ethereum .env
source .env

forge script script/xfer.s.sol:Transfer --rpc-url $RPC_URL -vvv --broadcast
