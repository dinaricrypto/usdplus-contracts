#!/bin/sh

cp .env-ethereum .env
source .env

forge script script/Deploy_02.s.sol:Deploy_02 --rpc-url $RPC_URL -vvv --broadcast --verify
