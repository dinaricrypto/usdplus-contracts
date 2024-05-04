// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";

contract Transfer is Script {
    function run() external {
        // load env variables
        uint256 userPrivateKey = vm.envUint("DEPLOYER_KEY");
        address user = vm.addr(userPrivateKey);
        address to = user;

        uint256 amount = 0.01 ether;

        console.log("user: %s", user);

        // send txs as user
        vm.startBroadcast(userPrivateKey);

        to.call{value: amount}("");

        vm.stopBroadcast();
    }
}
