#!/bin/sh

forge script script/Upgrade_027_028.s.sol:Upgrade_027_028 --rpc-url $RPC_URL -vvv --broadcast --skip-simulation --slow --verify --verifier blockscout --verifier-url https://explorer.kinto.xyz/api
