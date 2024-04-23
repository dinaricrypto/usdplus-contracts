#!/bin/sh

cp .env-arbitrum-sepolia .env
source .env

forge script script/Deploy_02.s.sol:Deploy_02 --rpc-url $RPC_URL -vvv --resume --verify
