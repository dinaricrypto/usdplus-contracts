#!/bin/sh

cp .env-sepolia .env
source .env

forge script script/Upgrade_redeemer_fix.s.sol:Upgrade_redeemer_fix --rpc-url $RPC_URL -vvv --broadcast --verify

cp .env-arbitrum .env
source .env

forge script script/Upgrade_redeemer_fix.s.sol:Upgrade_redeemer_fix --rpc-url $RPC_URL -vvv --broadcast --verify

cp .env-ethereum .env
source .env

forge script script/Upgrade_redeemer_fix.s.sol:Upgrade_redeemer_fix --rpc-url $RPC_URL -vvv --broadcast --verify
