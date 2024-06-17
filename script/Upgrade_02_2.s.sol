// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {UsdPlus} from "../src/UsdPlus.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract Upgrade is Script {
    struct DeployConfig {
        address owner;
        UsdPlus usdPlus;
    }

    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        DeployConfig memory cfg = DeployConfig({owner: deployer, usdPlus: UsdPlus(vm.envAddress("USDPLUS"))});

        console.log("deployer: %s", deployer);

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        /// ------------------ usd+ ------------------

        UsdPlus usdPlusImpl = new UsdPlus();
        cfg.usdPlus.upgradeToAndCall(address(usdPlusImpl), "");

        vm.stopBroadcast();
    }
}
