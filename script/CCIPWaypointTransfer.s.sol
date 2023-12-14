// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import {CCIPWaypoint} from "../src/bridge/CCIPWaypoint.sol";
import {UsdPlus} from "../src/UsdPlus.sol";

contract CCIPWaypointTransfer is Script {
    struct Config {
        address deployer;
        UsdPlus usdPlus;
        CCIPWaypoint ccipWaypoint;
        uint64 dest;
        address receiver;
    }

    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");

        Config memory cfg = Config({
            deployer: vm.addr(deployerPrivateKey),
            usdPlus: UsdPlus(vm.envAddress("USDPLUS")),
            ccipWaypoint: CCIPWaypoint(vm.envAddress("CCIP_MINTER")),
            dest: uint64(vm.envUint("CCIP_DEST")),
            receiver: vm.envAddress("CCIP_RECEIVER")
        });

        uint256 amount = 10 * 10 ** cfg.usdPlus.decimals();

        console.log("deployer: %s", cfg.deployer);

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        // approve
        cfg.usdPlus.approve(address(cfg.ccipWaypoint), amount);

        // get fee
        uint256 fee = cfg.ccipWaypoint.getFee(cfg.dest, cfg.receiver, cfg.deployer, amount, false);

        // send to bridge
        bytes32 messageId = cfg.ccipWaypoint.sendUsdPlus{value: fee}(cfg.dest, cfg.deployer, amount, false);

        console.log("messageId");
        console.logBytes32(messageId);

        vm.stopBroadcast();
    }
}
