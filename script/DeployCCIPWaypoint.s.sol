// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import {CCIPWaypoint} from "../src/bridge/CCIPWaypoint.sol";
import {UsdPlus} from "../src/UsdPlus.sol";
import {StakedUsdPlus} from "../src/StakedUsdPlus.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployCCIPWaypoint is Script {
    struct DeployConfig {
        address deployer;
        UsdPlus usdPlus;
        StakedUsdPlus stakedUsdPlus;
        address ccipRouter;
    }

    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");

        DeployConfig memory cfg = DeployConfig({
            deployer: vm.addr(deployerPrivateKey),
            usdPlus: UsdPlus(vm.envAddress("USDPLUS")),
            stakedUsdPlus: StakedUsdPlus(vm.envAddress("STAKEDUSDPLUS")),
            ccipRouter: vm.envAddress("CCIP_ROUTER")
        });

        console.log("deployer: %s", cfg.deployer);

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        CCIPWaypoint ccipWaypointImpl = new CCIPWaypoint();
        CCIPWaypoint ccipWaypoint = CCIPWaypoint(
            address(
                new ERC1967Proxy(
                    address(ccipWaypointImpl),
                    abi.encodeCall(
                        CCIPWaypoint.initialize, (cfg.usdPlus, cfg.stakedUsdPlus, cfg.ccipRouter, cfg.deployer)
                    )
                )
            )
        );

        // Remember to configure after both waypoints are deployed
        // ccipWaypoint.setApprovedReceiver();

        vm.stopBroadcast();
    }
}
