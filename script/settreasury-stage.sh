#!/bin/sh

cp .env-staging .env
source .env

forge script script/SetTreasury.s.sol:SetTreasury --rpc-url $RPC_URL -vvv --broadcast
