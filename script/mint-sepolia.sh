#!/bin/sh

cp .env-sepolia .env
source .env

forge script script/Mint.s.sol:Mint --rpc-url $RPC_URL -vvv --broadcast
