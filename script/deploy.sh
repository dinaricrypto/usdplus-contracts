#!/bin/sh
# Deploys to multiple blockchains using release.sh
#
# Required environment variables:
# ENVIRONMENT        - Target environment ["staging", "production"]
# AWS_SECRET_ID      - ARN of AWS secret to use

CHAIN_IDS=("11155111") # Chains to release to

# Retrieve secrets from AWS
CHAIN_SECRETS=$(aws secretsmanager get-secret-value --secret-id "${AWS_SECRET_ID}" --query SecretString --output text)

for chain_id in "${CHAIN_IDS[@]}"; do
  echo "Chain $chain_id: Deploying"

  VERSION="1.0.0" \
    RPC_URL=$(echo "${CHAIN_SECRETS}" | jq --raw-output .RPC_URL_${chain_id}) \
    PRIVATE_KEY=$(echo "${CHAIN_SECRETS}" | jq --raw-output .PRIVATE_KEY) \
    VERIFIER_URL=$(echo "${CHAIN_SECRETS}" | jq --raw-output ".VERIFIER_URL_${chain_id} // empty") \
    ETHERSCAN_API_KEY=$(echo "${CHAIN_SECRETS}" | jq --raw-output ".ETHERSCAN_API_KEY_${chain_id} // empty") \
    ./script/release.sh

  echo "Chain $chain_id: Deployed"
done

yarn build:releases $ENVIRONMENT $VERSION
yarn prettier:releases
