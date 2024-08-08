#!/bin/sh

cp .env-sandbox .env
source .env

forge create src/mocks/UnityOracle.sol:UnityOracle --rpc-url $RPC_URL --private-key $DEPLOYER_KEY --verify
