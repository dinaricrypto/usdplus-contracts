#!/bin/sh

cp .env-arbitrum .env
source .env

forge script script/Upgrade_02.s.sol:Upgrade_02 --rpc-url $RPC_URL -vvv
