// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {UsdPlus} from "../../src/UsdPlus.sol";
import {UsdPlusRedeemer} from "../../src/UsdPlusRedeemer.sol";
import {UsdPlusMinter} from "../../src/UsdPlusMinter.sol";

contract Upgrade_010_011 is Script {
    struct DeployConfig {
        address deployer;
        UsdPlus usdPlus;
        UsdPlusRedeemer usdPlusRedeemer;
        UsdPlusMinter usdPlusMinter;
    }

    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");

        DeployConfig memory cfg = DeployConfig({
            deployer: vm.addr(deployerPrivateKey),
            usdPlus: UsdPlus(vm.envAddress("USDPLUS")),
            usdPlusRedeemer: UsdPlusRedeemer(vm.envAddress("USDPLUS_REDEEMER")),
            usdPlusMinter: UsdPlusMinter(vm.envAddress("USDPLUS_MINTER"))
        });

        console.log("deployer: %s", cfg.deployer);

        vm.startBroadcast(deployerPrivateKey);

        // upgrade UsdPlus
        UsdPlus usdPlusImpl = new UsdPlus();
        cfg.usdPlus.upgradeToAndCall(address(usdPlusImpl), "");

        // upgrade UsdPlusRedeemer
        UsdPlusRedeemer usdPlusRedeemerImpl = new UsdPlusRedeemer();
        cfg.usdPlusRedeemer.upgradeToAndCall(address(usdPlusRedeemerImpl), "");

        // configure UsdPlus
        cfg.usdPlus.setIssuerLimits(address(cfg.usdPlusRedeemer), 0, type(uint256).max);
        cfg.usdPlus.setIssuerLimits(address(cfg.usdPlusMinter), type(uint256).max, 0);

        vm.stopBroadcast();
    }
}
