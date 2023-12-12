// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import {CCIPMinter} from "../src/bridge/CCIPMinter.sol";
import {UsdPlus} from "../src/UsdPlus.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployCCIPBridge is Script {
    struct DeployConfig {
        address deployer;
        UsdPlus usdPlus;
        address ccipRouter;
    }

    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");

        DeployConfig memory cfg = DeployConfig({
            deployer: vm.addr(deployerPrivateKey),
            usdPlus: UsdPlus(vm.envAddress("USDPLUS")),
            ccipRouter: vm.envAddress("CCIP_ROUTER")
        });

        console.log("deployer: %s", cfg.deployer);

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        CCIPMinter ccipMinterImpl = new CCIPMinter();
        CCIPMinter ccipMinter = CCIPMinter(
            address(
                new ERC1967Proxy(
                    address(ccipMinterImpl),
                    abi.encodeCall(CCIPMinter.initialize, (cfg.usdPlus, cfg.ccipRouter, cfg.deployer))
                )
            )
        );

        // ccipMinter.setApprovedReceiver();

        vm.stopBroadcast();
    }
}
