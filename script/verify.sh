#!/bin/sh

cp .env-arbitrum-sepolia .env
source .env

# proxy
# forge verify-contract --chain-id 421614 --watch --constructor-args $(cast abi-encode "constructor(address,bytes)" "0xF59550E0182aF47cbFEd4B30AC6A7235cac28945" "0xc0c53b8b00000000000000000000000009e365acdb0d936dd250351ad0e7de3dad8706e500000000000000000000000047ef9a1e9c35d4b15ba133820b6a83e9794379e80000000000000000000000004181803232280371e02a875f51515be57b215231") 0xEB37527713A4612be712395E05160997fC40bfB9 lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy
# no args
forge verify-contract --chain-id 421614 --watch 0xF59550E0182aF47cbFEd4B30AC6A7235cac28945 src/UsdPlus.sol:UsdPlus
# forge verify-contract --chain-id 1 --watch 0xEdA6e4Bf8CbfD0e25D4cbEacbeA2881546B4AEA3 src/StakedUsdPlus.sol:StakedUsdPlus
