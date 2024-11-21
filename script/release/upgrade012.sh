#!/bin/sh

cp .env-sepolia .env
source .env

forge script script/Upgrade_011_012.s.sol:Upgrade_011_012 --rpc-url $RPC_URL -vvv --broadcast --verify

cp .env-base-goerli .env
source .env

forge script script/Upgrade_011_012.s.sol:Upgrade_011_012 --rpc-url $RPC_URL -vvv --broadcast --verify

cp .env-arbitrum .env
source .env

forge script script/Upgrade_011_012.s.sol:Upgrade_011_012 --rpc-url $RPC_URL -vvv --broadcast --verify

cp .env-ethereum .env
source .env

forge script script/Upgrade_011_012.s.sol:Upgrade_011_012 --rpc-url $RPC_URL -vvv --broadcast --verify
