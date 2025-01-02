#!/bin/sh

forge create src/mocks/OracleMock.sol:OracleMock --rpc-url $RPC_URL --private-key $DEPLOY_KEY --verify --verifier blockscout --broadcast
