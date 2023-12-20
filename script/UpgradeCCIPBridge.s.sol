// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import {CCIPWaypoint} from "../src/bridge/CCIPWaypoint.sol";

contract UpgradeCCIPBridge is Script {
    struct DeployConfig {
        address deployer;
        CCIPWaypoint ccipWaypoint;
    }

    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");

        DeployConfig memory cfg = DeployConfig({
            deployer: vm.addr(deployerPrivateKey),
            ccipWaypoint: CCIPWaypoint(vm.envAddress("CCIP_MINTER"))
        });

        console.log("deployer: %s", cfg.deployer);

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        CCIPWaypoint ccipWaypointImpl = new CCIPWaypoint();
        cfg.ccipWaypoint.upgradeToAndCall(address(ccipWaypointImpl), "");

        vm.stopBroadcast();
    }
}
