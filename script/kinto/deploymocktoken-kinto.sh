#!/bin/sh

cp .env-kinto-stage .env
source .env

forge script script/kinto/DeployMockTokenCreate2.s.sol:DeployMockTokenCreate2 --rpc-url $RPC_URL -vvvv --broadcast --skip-simulation
# forge verify-contract --watch 0x90AB5E52Dfcce749CA062f4e04292fd8a67E86b3 src/mocks/ERC20Mock.sol:ERC20Mock --verifier blockscout --verifier-url https://explorer.kinto.xyz/api --chain-id 7887
