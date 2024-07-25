#!/bin/sh

cp .env-kinto-prod .env
source .env

forge script script/SetPaymentRecipient.s.sol:SetPaymentRecipient --rpc-url $RPC_URL -vvv --broadcast --skip-simulation
