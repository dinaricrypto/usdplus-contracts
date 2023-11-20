#!/bin/sh

# args
# forge verify-contract --chain-id 11155111 --watch --constructor-args $(cast abi-encode "constructor(address,bytes)" "0x658875Ad4d31735B0dA3Ed82E22DF3008D713b37" "0xc0c53b8b0000000000000000000000009303a17f11459a0c0d5b59ce4bc3880269ec94b50000000000000000000000004181803232280371e02a875f51515be57b2152310000000000000000000000004181803232280371e02a875f51515be57b215231") 0x3c34a5ACBD6Cf3e2305384276a7845A336a66041 lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy
# no args
forge verify-contract --chain-id 11155111 --watch 0x620Cb13F90D06C59ebCa43C433468981aE5fA678 src/UsdPlusRedeemer.sol:UsdPlusRedeemer
