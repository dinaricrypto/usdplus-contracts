#!/bin/sh

cp .env-arbitrum-sepolia .env
source .env

forge script script/RedeemMulticall.s.sol:RedeemMulticall --rpc-url $RPC_URL -vvv
