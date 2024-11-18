// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {UsdPlusMinter} from "../../src/UsdPlusMinter.sol";

contract Upgrade_023_024 is Script {
    struct DeployConfig {
        address deployer;
        UsdPlusMinter usdPlusMinter;
    }

    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");

        DeployConfig memory cfg =
            DeployConfig({deployer: vm.addr(deployerPrivateKey), usdPlusMinter: UsdPlusMinter(vm.envAddress("MINTER"))});

        console.log("deployer: %s", cfg.deployer);

        vm.startBroadcast(deployerPrivateKey);

        UsdPlusMinter usdPlusMinterImpl = new UsdPlusMinter();
        cfg.usdPlusMinter.upgradeToAndCall(address(usdPlusMinterImpl), "");

        vm.stopBroadcast();
    }
}
