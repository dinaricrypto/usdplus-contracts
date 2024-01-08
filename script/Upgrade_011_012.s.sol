// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import {UsdPlus} from "../src/UsdPlus.sol";

contract Upgrade_011_012 is Script {
    struct DeployConfig {
        address deployer;
        UsdPlus usdPlus;
    }

    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");

        DeployConfig memory cfg =
            DeployConfig({deployer: vm.addr(deployerPrivateKey), usdPlus: UsdPlus(vm.envAddress("USDPLUS"))});

        console.log("deployer: %s", cfg.deployer);

        vm.startBroadcast(deployerPrivateKey);

        // upgrade UsdPlus
        UsdPlus usdPlusImpl = new UsdPlus();
        cfg.usdPlus.upgradeToAndCall(address(usdPlusImpl), "");

        vm.stopBroadcast();
    }
}
