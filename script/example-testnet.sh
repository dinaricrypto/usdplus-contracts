#!/bin/sh

source .env

forge script script/MintEarnRedeem.s.sol:MintEarnRedeem --rpc-url $TEST_RPC_URL -vvv
