#!/bin/sh

cp .env-ethereum .env
source .env

forge script script/Roles.s.sol:Roles --rpc-url $RPC_URL -vvv --broadcast

cp .env-arbitrum .env
source .env

forge script script/Roles.s.sol:Roles --rpc-url $RPC_URL -vvv --broadcast

# cp .env-arbitrum-sepolia .env
# source .env

# forge script script/Roles.s.sol:Roles --rpc-url $RPC_URL -vvv --broadcast

# cp .env-sepolia .env
# source .env

# forge script script/Roles.s.sol:Roles --rpc-url $RPC_URL -vvv --broadcast
