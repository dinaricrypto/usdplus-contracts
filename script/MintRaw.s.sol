// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {ERC20Mock} from "../src/mocks/ERC20Mock.sol";
import {UsdPlus} from "../src/UsdPlus.sol";

contract MintRaw is Script {
    function run() external {
        // load env variables
        uint256 key = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(key);

        UsdPlus usdPlus = UsdPlus(vm.envAddress("USDPLUS"));

        address user = address(0);
        uint256 amount = 100 * 10 ** usdPlus.decimals();

        console.log("deployer: %s", deployer);
        console.log("user: %s", user);

        // send txs as user
        vm.startBroadcast(key);

        // mint usd+
        usdPlus.mint(user, amount);
        uint256 usdplusBalance = usdPlus.balanceOf(user);
        console.log("user %s USD+", usdplusBalance);

        vm.stopBroadcast();
    }
}
