#!/bin/sh

cp .env-arbitrum .env
source .env

forge script script/SetOracle.s.sol:SetOracle --rpc-url $RPC_URL -vvv --broadcast

cp .env-base .env
source .env

forge script script/SetOracle.s.sol:SetOracle --rpc-url $RPC_URL -vvv --broadcast

cp .env-ethereum .env
source .env

forge script script/SetOracle.s.sol:SetOracle --rpc-url $RPC_URL -vvv --broadcast

cp .env-sandbox .env
source .env

forge script script/SetOracle.s.sol:SetOracle --rpc-url $RPC_URL -vvv --broadcast
