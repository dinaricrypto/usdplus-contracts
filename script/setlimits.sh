#!/bin/sh

cp .env-arbitrum-sepolia .env
source .env

forge script script/SetMintBurnLimits.s.sol:SetMintBurnLimits --rpc-url $RPC_URL -vvv --broadcast
