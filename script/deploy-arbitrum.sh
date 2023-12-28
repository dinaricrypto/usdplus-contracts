#!/bin/sh

cp .env-arbitrum .env
source .env

forge script script/DeployAll.s.sol:DeployAll --rpc-url $RPC_URL -vvv --broadcast --verify
