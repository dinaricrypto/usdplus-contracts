// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {ERC20Mock} from "../src/mocks/ERC20Mock.sol";
import {UsdPlus} from "../src/UsdPlus.sol";
import {UsdPlusMinter} from "../src/UsdPlusMinter.sol";

contract Roles is Script {
    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        UsdPlus usdPlus = UsdPlus(vm.envAddress("USDPLUS"));

        address account = 0x400880b800410B2951Afd0503dC457aea8A4bAb5;

        console.log("deployer: %s", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // add rebase operator
        usdPlus.grantRole(usdPlus.OPERATOR_ROLE(), account);
        // unlimited mint/burn
        usdPlus.setIssuerLimits(account, type(uint256).max, type(uint256).max);

        vm.stopBroadcast();
    }
}
