// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";

contract Mint is Script {
    function run() external {
        // load env variables
        uint256 userPrivateKey = vm.envUint("DEPLOYER_KEY");
        address user = vm.addr(userPrivateKey);
        address to = 0x2bF22fD411C71b698bF6e0e937b1B948339Ec369;

        uint256 amount = 0.5 ether;

        console.log("user: %s", user);

        // send txs as user
        vm.startBroadcast(userPrivateKey);

        to.call{value: amount}("");

        vm.stopBroadcast();
    }
}
