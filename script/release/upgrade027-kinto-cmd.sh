#!/bin/sh

forge script script/Upgrade_026_027.s.sol:Upgrade_026_027 --rpc-url $RPC_URL -vvv --broadcast --skip-simulation --slow --verify --verifier blockscout --verifier-url https://explorer.kinto.xyz/api
