#!/bin/sh

cp .env-sepolia .env
source .env

forge script script/Upgrade_021_022.s.sol:Upgrade_021_022 --rpc-url $RPC_URL -vvv --broadcast --verify

cp .env-arbitrum-sepolia .env
source .env

forge script script/Upgrade_021_022.s.sol:Upgrade_021_022 --rpc-url $RPC_URL -vvv --broadcast --verify

cp .env-base-sepolia .env
source .env

forge script script/Upgrade_021_022.s.sol:Upgrade_021_022 --rpc-url $RPC_URL -vvv --broadcast --verify

cp .env-sandbox .env
source .env

forge script script/Upgrade_021_022.s.sol:Upgrade_021_022 --rpc-url $RPC_URL -vvv --broadcast --slow --verify

cp .env-arbitrum .env
source .env

forge script script/Upgrade_021_022.s.sol:Upgrade_021_022 --rpc-url $RPC_URL -vvv --broadcast --verify

cp .env-ethereum .env
source .env

forge script script/Upgrade_021_022.s.sol:Upgrade_021_022 --rpc-url $RPC_URL -vvv --broadcast --verify

cp .env-base .env
source .env

forge script script/Upgrade_021_022.s.sol:Upgrade_021_022 --rpc-url $RPC_URL -vvv --broadcast --verify
