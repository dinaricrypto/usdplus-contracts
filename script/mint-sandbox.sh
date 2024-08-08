#!/bin/sh

cp .env-sandbox .env
source .env

forge script script/Mint.s.sol:Mint --rpc-url $RPC_URL -vvv --broadcast
