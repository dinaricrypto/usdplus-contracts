#!/bin/sh

forge create src/mocks/UnityOracle.sol:UnityOracle --rpc-url $RPC_URL --private-key $DEPLOYER_KEY --verify
