// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import {CCIPMinter} from "../src/bridge/CCIPMinter.sol";
import {UsdPlus} from "../src/UsdPlus.sol";

contract CCIPBridgeTransfer is Script {
    struct Config {
        address deployer;
        UsdPlus usdPlus;
        CCIPMinter ccipMinter;
        uint64 dest;
        address receiver;
    }

    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");

        Config memory cfg = Config({
            deployer: vm.addr(deployerPrivateKey),
            usdPlus: UsdPlus(vm.envAddress("USDPLUS")),
            ccipMinter: CCIPMinter(vm.envAddress("CCIP_MINTER")),
            dest: uint64(vm.envUint("CCIP_DEST")),
            receiver: vm.envAddress("CCIP_RECEIVER")
        });

        uint256 amount = 10 * 10 ** cfg.usdPlus.decimals();

        console.log("deployer: %s", cfg.deployer);

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        // approve
        cfg.usdPlus.approve(address(cfg.ccipMinter), amount);

        // get fee
        uint256 fee = cfg.ccipMinter.getFee(cfg.dest, cfg.receiver, cfg.deployer, amount);

        // send to bridge
        bytes32 messageId = cfg.ccipMinter.burnAndMint{value: fee}(cfg.dest, cfg.receiver, cfg.deployer, amount);

        console.log("messageId");
        console.logBytes32(messageId);

        vm.stopBroadcast();
    }
}
