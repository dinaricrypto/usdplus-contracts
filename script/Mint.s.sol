// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import {ERC20Mock} from "../src/mocks/ERC20Mock.sol";
import {UsdPlus} from "../src/UsdPlus.sol";
import {UsdPlusMinter} from "../src/UsdPlusMinter.sol";

contract Mint is Script {
    struct DeployConfig {
        ERC20Mock usdc;
        UsdPlus usdPlus;
        UsdPlusMinter minter;
    }

    function run() external {
        // load env variables
        uint256 userPrivateKey = vm.envUint("USER_KEY");
        address user = vm.addr(userPrivateKey);

        DeployConfig memory cfg = DeployConfig({
            usdc: ERC20Mock(vm.envAddress("USDC")),
            usdPlus: UsdPlus(vm.envAddress("USDPLUS")),
            minter: UsdPlusMinter(vm.envAddress("MINTER"))
        });

        uint256 amount = 1000 * 10 ** cfg.usdc.decimals();

        console.log("user: %s", user);

        // send txs as user
        vm.startBroadcast(userPrivateKey);

        // mint usd+
        cfg.usdc.approve(address(cfg.minter), amount);
        cfg.minter.deposit(cfg.usdc, amount, user);
        uint256 usdplusBalance = cfg.usdPlus.balanceOf(user);
        console.log("user %s USD+", usdplusBalance);

        vm.stopBroadcast();
    }
}
