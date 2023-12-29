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

        Config memory cfg =
            Config({deployer: vm.addr(deployerPrivateKey), ccipWaypoint: CCIPWaypoint(vm.envAddress("CCIP_WAYPOINT"))});

        // Ethereum
        // uint64 chain = 5009297550715157269;
        // address remoteWaypoint = 0xF83042d4bbb1cB9C9e1042da4654585C60f6FFdc;
        // Arbitrum One
        // uint64 chain = 4949039107694359620;
        // address remoteWaypoint = 0x3A34b7Fa417B51af57936f72b8234C824F816907;
        // Sepolia
        // uint64 chain = 16015286601757825753;
        // address remoteWaypoint = 0xE6BD08DA06c0ee96443127007FFD468C46929074;
        // Base Goerli
        uint64 chain = 5790810961207155433;
        address remoteWaypoint = 0xC979d29237bBF6d9Fa3febDB07Bb8e39ca774dEE;

        console.log("deployer: %s", cfg.deployer);

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        cfg.ccipWaypoint.setApprovedReceiver(chain, remoteWaypoint);
        cfg.ccipWaypoint.setApprovedSender(chain, remoteWaypoint);

        vm.stopBroadcast();
    }
}
