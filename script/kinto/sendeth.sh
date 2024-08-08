#!/bin/sh

cp .env-kinto-prod .env
source .env

cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY 0x2bF22fD411C71b698bF6e0e937b1B948339Ec369 --value 0.004ether
