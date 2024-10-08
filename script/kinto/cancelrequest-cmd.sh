#!/bin/sh

forge script script/kinto/CancelRequest.s.sol:CancelRequest --rpc-url $RPC_URL -vvv --broadcast --skip-simulation
