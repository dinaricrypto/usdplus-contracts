// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {CCIPWaypoint} from "../../src/bridge/CCIPWaypoint.sol";
import {UsdPlus} from "../../src/UsdPlus.sol";

contract WaypointTransferTest is Test {
    struct Config {
        address deployer;
        UsdPlus usdPlus;
        CCIPWaypoint ccipWaypoint;
        uint64 dest;
        address receiver;
    }

    function test_run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");

        Config memory cfg = Config({
            deployer: vm.addr(deployerPrivateKey),
            usdPlus: UsdPlus(vm.envAddress("USDPLUS")),
            ccipWaypoint: CCIPWaypoint(vm.envAddress("CCIP_WAYPOINT")),
            dest: uint64(vm.envUint("CCIP_DEST")),
            receiver: vm.envAddress("CCIP_RECEIVER")
        });

        uint256 amount = 1499955;

        console.log("deployer: %s", cfg.deployer);

        // send txs as deployer
        // vm.startBroadcast(deployerPrivateKey);
        vm.startPrank(cfg.deployer);

        // approve
        // cfg.usdPlus.approve(address(cfg.ccipWaypoint), amount);

        // get fee
        uint256 fee = cfg.ccipWaypoint.getFee(cfg.dest, cfg.receiver, cfg.deployer, amount);
        console.log("fee: %d", fee);

        // send to bridge
        bytes32 messageId = cfg.ccipWaypoint.sendUsdPlus{value: fee}(cfg.dest, cfg.deployer, amount);

        console.log("messageId");
        console.logBytes32(messageId);

        vm.stopPrank();
        // vm.stopBroadcast();
    }
}
