#!/bin/sh

forge script script/Upgrade_025_026.s.sol:Upgrade_025_026 --rpc-url $RPC_URL -vvv --broadcast --skip-simulation --slow --verify --verifier blockscout --verifier-url https://explorer.kinto.xyz/api
