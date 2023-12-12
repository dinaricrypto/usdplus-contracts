#!/bin/sh

cp .env-sepolia .env
source .env

forge script script/GrantRole.s.sol:GrantRole --rpc-url $RPC_URL -vvv --broadcast
