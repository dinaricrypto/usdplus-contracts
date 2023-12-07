#!/bin/sh

# proxy
# forge verify-contract --chain-id 1 --watch --constructor-args $(cast abi-encode "constructor(address,bytes)" "0x63914c467eA6C16EA85514DBC32b9Ee2ae179e8e" "0x485cc95500000000000000000000000098c6616f1cc0d3e938a16200830dd55663dd7dd3000000000000000000000000269e944ad9140fc6e21794e8ea71ce1afbfe38c8") 0xe1B2FEEDE3ffE7e63a89A669A08688951c94611e lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy
# no args
forge verify-contract --chain-id 11155111 --watch 0xa26822D06bD4efC994109D6Bf5D0478a9b57f6fe src/UsdPlus.sol:UsdPlus
