// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {CCIPWaypoint} from "../../src/bridge/CCIPWaypoint.sol";

contract PrintWaypointConfig is Script {
    struct CCIPChain {
        uint64 id;
        string name;
    }

    function run() external view {
        // load env variables
        CCIPWaypoint ccipWaypoint = CCIPWaypoint(vm.envAddress("CCIP_WAYPOINT"));

        // chains
        CCIPChain[] memory chains = new CCIPChain[](2);
        chains[0] = CCIPChain({id: 5009297550715157269, name: "eth"});
        chains[1] = CCIPChain({id: 4949039107694359620, name: "arb"});

        console.log("CCIP Waypoint Config");

        // chainid
        console.log("chainid: %s", block.chainid);

        // router
        console.log("router: %s", ccipWaypoint.getRouter());

        // is paused
        console.log("is paused: %s", ccipWaypoint.paused());

        console.log("");
        console.log("Chains");
        for (uint256 i = 0; i < chains.length; i++) {
            // chain
            console.log("%s: %s", chains[i].name, chains[i].id);

            // approved sender
            console.log("approved sender: %s", ccipWaypoint.getApprovedSender(chains[i].id));

            // approved receiver
            console.log("approved receiver: %s", ccipWaypoint.getApprovedReceiver(chains[i].id));

            console.log("");
        }
    }
}
