// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {UsdPlus} from "../../src/UsdPlus.sol";

contract MintDirect is Script {
    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        UsdPlus usdplus = UsdPlus(0xe1605b6B2748E46234389b9107C829e33F2dB65c);

        console.log("deployer: %s", deployer);

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        usdplus.setIssuerLimits(deployer, type(uint256).max, type(uint256).max);

        usdplus.mint(deployer, 10 ** 6);

        usdplus.burn(deployer, 10 ** 6);

        vm.stopBroadcast();
    }
}
