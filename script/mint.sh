#!/bin/sh

cp .env-arbitrum .env
source .env

forge script script/Mint.s.sol:Mint --rpc-url $RPC_URL -vvv --broadcast
