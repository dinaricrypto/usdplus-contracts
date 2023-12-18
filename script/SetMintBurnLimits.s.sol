// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import {UsdPlus} from "../src/UsdPlus.sol";

contract SetMintBurnLimits is Script {
    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        UsdPlus usdPlus = UsdPlus(vm.envAddress("USDPLUS"));
        address ccipWaypoint = vm.envAddress("CCIP_WAYPOINT");

        console.log("deployer: %s", deployer);

        // send txs as user
        vm.startBroadcast(deployerPrivateKey);

        usdPlus.setIssuerLimits(ccipWaypoint, type(uint256).max, type(uint256).max);

        vm.stopBroadcast();
    }
}
