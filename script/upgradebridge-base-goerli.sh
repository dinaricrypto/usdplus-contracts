#!/bin/sh

cp .env-base-goerli .env
source .env

forge script script/UpgradeCCIPBridge.s.sol:UpgradeCCIPBridge --rpc-url $RPC_URL -vvv --broadcast --verify
