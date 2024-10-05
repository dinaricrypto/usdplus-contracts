#!/bin/sh

forge script script/Upgrade_024_025.s.sol:Upgrade_024_025 --rpc-url $RPC_URL -vvv --broadcast --skip-simulation --slow --verify --verifier blockscout --verifier-url https://explorer.kinto.xyz/api
