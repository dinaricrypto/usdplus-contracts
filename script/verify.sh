#!/bin/sh

forge verify-contract --chain-id 11155111 --watch --constructor-args $(cast abi-encode "constructor(address,address,address)" "0x4181803232280371E02a875F51515BE57B215231" "0xb3Db29a0088716F17e8c89ba1166A7292A7C22eF" "0x4181803232280371E02a875F51515BE57B215231") 0xe14f22C0dcD91a9CA1A007B6f733335195bcEB9B src/UsdPlus.sol:UsdPlus
