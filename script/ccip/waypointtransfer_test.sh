#!/bin/sh

cp .env-arbitrum-sepolia .env
source .env

forge test -f $RPC_URL --match-path test/bridge/WaypointTransfer.t.sol --debug test_run
# forge script script/ccip/WaypointTransfer.s.sol:WaypointTransfer --rpc-url $RPC_URL -vvv
