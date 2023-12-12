// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import {CCIPMinter} from "../src/bridge/CCIPMinter.sol";

contract UpgradeCCIPBridge is Script {
    struct DeployConfig {
        address deployer;
        CCIPMinter ccipMinter;
    }

    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");

        DeployConfig memory cfg =
            DeployConfig({deployer: vm.addr(deployerPrivateKey), ccipMinter: CCIPMinter(vm.envAddress("CCIP_MINTER"))});

        console.log("deployer: %s", cfg.deployer);

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        CCIPMinter ccipMinterImpl = new CCIPMinter();
        cfg.ccipMinter.upgradeToAndCall(address(ccipMinterImpl), "");

        vm.stopBroadcast();
    }
}
