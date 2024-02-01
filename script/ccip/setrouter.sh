#!/bin/sh

cp .env-sepolia .env
source .env

forge script script/ccip/SetRouter.s.sol:SetRouter --rpc-url $RPC_URL -vvv --broadcast

cp .env-base-goerli .env
source .env

forge script script/ccip/SetRouter.s.sol:SetRouter --rpc-url $RPC_URL -vvv --broadcast

cp .env-arbitrum .env
source .env

forge script script/ccip/SetRouter.s.sol:SetRouter --rpc-url $RPC_URL -vvv --broadcast

cp .env-ethereum .env
source .env

forge script script/ccip/SetRouter.s.sol:SetRouter --rpc-url $RPC_URL -vvv --broadcast
