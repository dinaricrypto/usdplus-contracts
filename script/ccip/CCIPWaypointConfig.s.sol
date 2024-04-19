// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import {CCIPWaypoint} from "../../src/bridge/CCIPWaypoint.sol";

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
        // address remoteWaypoint = 0xe3dE80F8dB28d1C2ebE6F1e8d42Ea4EaA572019E;
        // Arbitrum Sepolia
        uint64 chain = 3478487238524512106;
        address remoteWaypoint = 0xE2fDf320cf771dd4eC1DbdB1B1CEd6003D672186;

        console.log("deployer: %s", cfg.deployer);

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        cfg.ccipWaypoint.setApprovedReceiver(chain, remoteWaypoint);
        cfg.ccipWaypoint.setApprovedSender(chain, remoteWaypoint);

        vm.stopBroadcast();
    }
}
