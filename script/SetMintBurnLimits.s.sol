// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {UsdPlus} from "../src/UsdPlus.sol";

contract SetMintBurnLimits is Script {
    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        UsdPlus usdPlus = UsdPlus(vm.envAddress("USDPLUS"));
        // address account = address(0);

        console.log("deployer: %s", deployer);

        // send txs as user
        vm.startBroadcast(deployerPrivateKey);

        // usdPlus.setIssuerLimits(0x4181803232280371E02a875F51515BE57B215231, type(uint256).max, type(uint256).max);
        usdPlus.setIssuerLimits(0x926b4a790555F2f87c2c4853f859706D9F349DAa, type(uint256).max, type(uint256).max);

        vm.stopBroadcast();
    }
}
