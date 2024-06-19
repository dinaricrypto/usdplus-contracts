#!/bin/sh

cp .env-kinto .env
source .env

forge script script/kinto/DeployAllCreate2.s.sol:DeployAllCreate2 --rpc-url $RPC_URL -vvvv --broadcast --skip-simulation
# forge verify-contract --watch 0x9637CC556e1baAb0B26eD1aACc308a0d5E9c1f0C src/UsdPlusRedeemer.sol:UsdPlusRedeemer --verifier blockscout --verifier-url https://explorer.kinto.xyz/api --chain-id 7887
