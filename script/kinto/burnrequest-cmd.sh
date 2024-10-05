#!/bin/sh

forge script script/kinto/BurnRequest.s.sol:BurnRequest --rpc-url $RPC_URL -vvvv --broadcast --skip-simulation
