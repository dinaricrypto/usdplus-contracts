#!/bin/bash

# Load environment variables
cp .env-local .env
source .env

# Deploy contracts
forge script script/Release.s.sol --rpc-url $RPC_URL -vvv