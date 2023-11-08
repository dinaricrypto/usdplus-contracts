#!/bin/sh

source .env

forge script script/MintEarnRedeemBundled.s.sol:MintEarnRedeemBundled --rpc-url $TEST_RPC_URL -vvv
