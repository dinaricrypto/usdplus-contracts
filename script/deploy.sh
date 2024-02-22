#!/bin/sh

cp .env-polygon .env
source .env

forge script script/DeployAll.s.sol:DeployAll --rpc-url $RPC_URL -vvv --verify --broadcast
# forge script script/DeployAll.s.sol:DeployAll --rpc-url $RPC_URL -vvv --verify --resume
