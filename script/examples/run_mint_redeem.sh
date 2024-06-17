#!/bin/sh

cp .env-arbitrum .env

npx ts-node script/examples/mint_redeem.ts
