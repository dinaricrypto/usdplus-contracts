#!/bin/sh

# cp .env-ethereum .env
# source .env

# forge script script/SetMintBurnLimits.s.sol:SetMintBurnLimits --rpc-url $RPC_URL -vvv --broadcast

# cp .env-arbitrum .env
# source .env

# forge script script/SetMintBurnLimits.s.sol:SetMintBurnLimits --rpc-url $RPC_URL -vvv --broadcast

cp .env-arbitrum-sepolia .env
source .env

forge script script/SetMintBurnLimits.s.sol:SetMintBurnLimits --rpc-url $RPC_URL -vvv --broadcast

cp .env-sepolia .env
source .env

forge script script/SetMintBurnLimits.s.sol:SetMintBurnLimits --rpc-url $RPC_URL -vvv --broadcast
