#!/bin/sh

cp .env-kinto .env
source .env

forge script script/kinto/DeployAllCreate2.s.sol:DeployAllCreate2 --rpc-url $RPC_URL -vvvv --broadcast --skip-simulation --verify --verifier blockscout --verifier-url https://explorer.kinto.xyz/api --chain-id 7887
# forge verify-contract --watch 0x92ebC5eD28C78E18bFE37A4761d1b6Ec5997d979 src/TransferRestrictor.sol:TransferRestrictor --verifier blockscout --verifier-url https://explorer.kinto.xyz/api --chain-id 7887
