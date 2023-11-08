#!/bin/sh

source .env-test

forge script script/MintEarnRedeemBundled.s.sol:MintEarnRedeemBundled --rpc-url $RPC_URL -vvv
