// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {UsdPlus} from "../src/UsdPlus.sol";

contract Upgrade_02 is Script {
    struct DeployConfig {
        address deployer;
        UsdPlus usdPlus;
    }

    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");

        DeployConfig memory cfg =
            DeployConfig({deployer: vm.addr(deployerPrivateKey), usdPlus: UsdPlus(vm.envAddress("USDPLUS"))});

        console.log("deployer: %s", cfg.deployer);

        address[] memory holders = new address[](4);
        holders[0] = 0x5C253d333D19C6A64c780D9ad5b5fe97a4a277BC;
        holders[1] = 0x47910F43ecA6a2355E8b1Ff5F60923939FBB8915;
        holders[2] = 0xe9477d7C207eC0004Fc7D6221dbB6a29b8d18083;
        holders[3] = 0x2855d241119Ce7Ad3ebeE690AC322a1cF03Ed46d;

        uint256[] memory amounts = new uint256[](holders.length);
        for (uint256 i = 0; i < holders.length; i++) {
            amounts[i] = cfg.usdPlus.balanceOf(holders[i]);
        }

        console.log("balanceBefore: %s", amounts[0]);

        vm.startBroadcast(deployerPrivateKey);

        // unstake all tokens

        // upgrade UsdPlus
        UsdPlus usdPlusImpl = new UsdPlus();
        cfg.usdPlus.upgradeToAndCall(address(usdPlusImpl), "");

        // mint all tokens
        // cfg.usdPlus.setIssuerLimits(cfg.deployer, type(uint256).max, type(uint256).max);
        for (uint256 i = 0; i < holders.length; i++) {
            cfg.usdPlus.mint(holders[i], amounts[i]);
        }

        console.log("balanceAfter: %s", cfg.usdPlus.balanceOf(holders[0]));

        vm.stopBroadcast();
    }
}
