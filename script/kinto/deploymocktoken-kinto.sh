#!/bin/sh

cp .env-kinto-stage .env
source .env

forge script script/kinto/DeployMockTokenCreate2.s.sol:DeployMockTokenCreate2 --rpc-url $RPC_URL -vvvv --broadcast --skip-simulation
# forge verify-contract --watch 0xcF7b16C8796681F2BBc2c9e5CE517a621356b5DC src/mocks/ERC20Mock.sol:ERC20Mock --verifier blockscout --verifier-url https://explorer.kinto.xyz/api --chain-id 7887
