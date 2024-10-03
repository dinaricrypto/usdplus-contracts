#!/bin/sh

forge script script/Upgrade_022_023.s.sol:Upgrade_022_023 --rpc-url $RPC_URL -vvv --broadcast --skip-simulation --slow --verify --verifier blockscout --verifier-url https://explorer.kinto.xyz/api
