#!/bin/sh

cp .env-ethereum .env
source .env

forge script script/Upgrade_02_2.s.sol:Upgrade --rpc-url $RPC_URL -vvv --broadcast --verify
