#!/bin/sh

cp .env-base-goerli .env
source .env

forge script script/SetMintBurnLimits.s.sol:SetMintBurnLimits --rpc-url $RPC_URL -vvv --broadcast
