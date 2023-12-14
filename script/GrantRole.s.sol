// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import {UsdPlus} from "../src/UsdPlus.sol";

contract GrantRole is Script {
    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        UsdPlus usdPlus = UsdPlus(vm.envAddress("USDPLUS"));
        address ccipWaypoint = vm.envAddress("CCIP_WAYPOINT");

        console.log("deployer: %s", deployer);

        // send txs as user
        vm.startBroadcast(deployerPrivateKey);

        usdPlus.grantRole(keccak256("MINTER_ROLE"), ccipWaypoint);
        usdPlus.grantRole(keccak256("BURNER_ROLE"), ccipWaypoint);

        vm.stopBroadcast();
    }
}
