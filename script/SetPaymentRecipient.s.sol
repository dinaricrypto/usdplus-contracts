// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {UsdPlusMinter} from "../src/UsdPlusMinter.sol";

contract SetPaymentRecipient is Script {
    function run() external {
        // Load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        UsdPlusMinter minter = UsdPlusMinter(vm.envAddress("MINTER"));

        console.log("deployer: %s", deployer);

        // Send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        minter.setPaymentRecipient(deployer);

        vm.stopBroadcast();
    }
}
