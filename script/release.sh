#!/bin/sh

# Required environment variables:
# ENVIRONMENT         - Target environment ["staging", "production"]
# RPC_URL            - RPC endpoint URL
# PRIVATE_KEY        - Deploy private key
#
# Optional:
# VERIFY_URL         - Contract verifier URL (if not using Etherscan)
# ETHERSCAN_API_KEY  - Etherscan API key
# DEPLOYED_VERSION   - Version of the previous deployment

export VERSION="1.0.0" # Version of current deployment

CONTRACTS=("UsdPlus" "TransferRestrictor" "UsdPlusMinter" "UsdPlusRedeemer" "CCIPWaypoint")

for i in "${CONTRACTS[@]}"; do
   echo "Deploying $i"
   export CONTRACT=$i
   
   FORGE_CMD="forge script script/Release.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast -vvv"
   
   if [ ! -z "$ETHERSCAN_API_KEY" ] || [ ! -z "$VERIFIER_URL" ]; then
       FORGE_CMD="$FORGE_CMD --verify"
   fi
   
   eval $FORGE_CMD || echo "Failed to deploy $i, continuing..."
done

echo "Deployment process completed."