#!/bin/bash
# Releases set of contracts to specified RPC url
#
# Required environment variables:
# VERSION            - Version of deployment
# ENVIRONMENT        - Target environment ["staging", "production"]
# RPC_URL            - RPC endpoint URL
# PRIVATE_KEY        - Deploy private key
#
# Optional:
# VERIFY_URL         - Contract verifier URL (if not using Etherscan)
# ETHERSCAN_API_KEY  - Etherscan API key
# DEPLOYED_VERSION   - Version of the previous deployment

CONTRACTS=("UsdPlus" "TransferRestrictor" "UsdPlusMinter" "UsdPlusRedeemer" "CCIPWaypoint")

for i in "${CONTRACTS[@]}"; do
  echo "$i: Releasing"

  FORGE_CMD="CONTRACT=$i FOUNDRY_DISABLE_NIGHTLY_WARNING=True forge script script/Release.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast -vvv"

  if [ ! -z "$ETHERSCAN_API_KEY" ] || [ ! -z "$VERIFIER_URL" ]; then
    FORGE_CMD="$FORGE_CMD --verify"
  fi

  eval $FORGE_CMD || echo "$i: Failed"
done
