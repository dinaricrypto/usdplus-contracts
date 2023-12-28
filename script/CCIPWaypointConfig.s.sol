// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import {CCIPWaypoint} from "../src/bridge/CCIPWaypoint.sol";

contract CCIPWaypointConfig is Script {
    struct Config {
        address deployer;
        CCIPWaypoint ccipWaypoint;
    }

    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");

        Config memory cfg = Config({
            deployer: vm.addr(deployerPrivateKey),
            ccipWaypoint: CCIPWaypoint(vm.envAddress("CCIP_WAYPOINT"))
        });

        uint64 chain = 4949039107694359620;
        address remoteWaypoint = 0x3A34b7Fa417B51af57936f72b8234C824F816907;

        console.log("deployer: %s", cfg.deployer);

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        cfg.ccipWaypoint.setApprovedReceiver(chain, remoteWaypoint);

        vm.stopBroadcast();
    }
}
