#!/bin/bash
# Executes the UpdateTransferRestrictorForUsdPlus script on the specified RPC URL
#
# Required environment variables:
# ENVIRONMENT        - Target environment ["staging", "production"]
# RPC_URL           - RPC endpoint URL
# CHAIN_ID          - Chain ID of RPC
# PRIVATE_KEY       - Deploy private key

echo "========================"
echo "UpdateTransferRestrictorForUsdPlus: Executing"

# Check required environment variables
if [ -z "$ENVIRONMENT" ] || [ -z "$RPC_URL" ] || [ -z "$CHAIN_ID" ] || [ -z "$PRIVATE_KEY" ]; then
  echo "Error: ENVIRONMENT, RPC_URL, CHAIN_ID, and PRIVATE_KEY must be set"
  exit 1
fi

# Base Forge command
FORGE_CMD="forge script script/UpdateTransferRestrictorForUsdPlus.s.sol -vvv --rpc-url $RPC_URL --private-key $PRIVATE_KEY --slow --broadcast --env ENVIRONMENT=$ENVIRONMENT"

# Append chain-specific modifications
if [ "$CHAIN_ID" == "98864" ] || [ "$CHAIN_ID" == "98865" ]; then
  FORGE_CMD="$FORGE_CMD --legacy --skip-simulation"
elif [ "$CHAIN_ID" == "7887" ]; then
  FORGE_CMD="$FORGE_CMD --skip-simulation"
fi

# Execute the command
FOUNDRY_DISABLE_NIGHTLY_WARNING=True $FORGE_CMD

echo "========================"