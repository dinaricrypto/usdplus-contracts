#!/bin/sh

cp .env-kinto .env
source .env

forge script script/DeployTokenOnly.s.sol:DeployTokenOnly --rpc-url $RPC_URL -vvvv --slow
