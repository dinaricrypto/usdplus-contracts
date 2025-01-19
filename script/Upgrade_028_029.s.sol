// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {UsdPlusRedeemer} from "../src/UsdPlusRedeemer.sol";

contract Upgrade_028_029 is Script {
    struct DeployConfig {
        address deployer;
        UsdPlusRedeemer usdPlusRedeemer;
    }

    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");

        DeployConfig memory cfg = DeployConfig({
            deployer: vm.addr(deployerPrivateKey),
            usdPlusRedeemer: UsdPlusRedeemer(vm.envAddress("REDEEMER"))
        });

        console.log("deployer: %s", cfg.deployer);

        vm.startBroadcast(deployerPrivateKey);

        UsdPlusRedeemer usdPlusRedeemerImpl = new UsdPlusRedeemer();
        cfg.usdPlusRedeemer.upgradeToAndCall(address(usdPlusRedeemerImpl), "");

        vm.stopBroadcast();
    }
}
