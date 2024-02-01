// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import {CCIPWaypoint} from "../../src/bridge/CCIPWaypoint.sol";

contract SetRouter is Script {
    struct Config {
        address deployer;
        CCIPWaypoint ccipWaypoint;
        address router;
    }

    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");

        Config memory cfg = Config({
            deployer: vm.addr(deployerPrivateKey),
            ccipWaypoint: CCIPWaypoint(vm.envAddress("CCIP_WAYPOINT")),
            router: vm.envAddress("CCIP_ROUTER")
        });

        console.log("deployer: %s", cfg.deployer);

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        cfg.ccipWaypoint.setRouter(cfg.router);

        vm.stopBroadcast();
    }
}
