#!/bin/bash

# Load environment variables
cp .env-local .env
source .env

# Deploy contracts
forge script script/DeployAndUpgradeManager.s.sol --rpc-url $RPC_URL -vvv

FILE_PATH="releases/v1/$(echo $CONTRACT | tr '[:upper:]' '[:lower:]').json"

echo "Current release file content:"
cat "$FILE_PATH"

echo -e "\nExtracting ABI from artifact..."
jq -r '.abi' "out/$CONTRACT.sol/$CONTRACT.json" > temp_abi.json

echo -e "\nABI content (first few lines):"
head -n 5 temp_abi.json

echo -e "\nMerging JSONs..."
# Preserve structure and update ABI
jq -s \
  '.[0] * {"abi": .[1]}' \
  <(cat "$FILE_PATH" | jq '.') \
  temp_abi.json > temp.json || {
    echo "Error merging JSONs"
    cat "$FILE_PATH"
    echo -e "\nABI file:"
    cat temp_abi.json
    exit 1
}

echo -e "\nFinal JSON (first few lines):"
head -n 5 temp.json

mv temp.json "$FILE_PATH"
rm temp_abi.json

echo "Successfully updated $FILE_PATH"