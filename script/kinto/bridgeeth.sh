#!/bin/sh

cp .env-kinto-prod .env
source .env

cast send --private-key $DEPLOYER_KEY --rpc-url https://eth-mainnet.g.alchemy.com/v2/5uAxJ6pXINCdocopqwg3IZuyLz_VDHbB 0xBFfaA85c1756472fFC37e6D172A7eC0538C14474 "depositEth()" --value 0.02ether
