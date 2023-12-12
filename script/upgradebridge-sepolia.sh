#!/bin/sh

cp .env-sepolia .env
source .env

forge script script/UpgradeCCIPBridge.s.sol:UpgradeCCIPBridge --rpc-url $RPC_URL -vvv --broadcast --verify
