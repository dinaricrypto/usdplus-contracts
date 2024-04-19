#!/bin/sh

cp .env-arbitrum-sepolia .env
source .env

forge script script/PullAndDeposit.s.sol:PullAndDeposit --rpc-url $RPC_URL -vvv --broadcast
