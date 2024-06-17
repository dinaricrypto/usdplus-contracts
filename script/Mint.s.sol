// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {ERC20Mock} from "../src/mocks/ERC20Mock.sol";
import {UsdPlusMinter} from "../src/UsdPlusMinter.sol";

contract Mint is Script {
    struct DeployConfig {
        ERC20Mock usdc;
        UsdPlusMinter minter;
    }

    function run() external {
        // load env variables
        uint256 userPrivateKey = vm.envUint("USER_KEY");
        address user = vm.addr(userPrivateKey);

        DeployConfig memory cfg = DeployConfig({
            usdc: ERC20Mock(vm.envAddress("USDC")),
            minter: UsdPlusMinter(vm.envAddress("USDPLUS_MINTER"))
        });

        uint256 amount = cfg.usdc.balanceOf(user);

        console.log("user: %s", user);

        // send txs as user
        vm.startBroadcast(userPrivateKey);

        // mint usd+
        cfg.usdc.approve(address(cfg.minter), amount);
        cfg.minter.deposit(cfg.usdc, amount, user);
        uint256 usdplusBalance = ERC20Mock(cfg.minter.usdplus()).balanceOf(user);
        console.log("user %s USD+", usdplusBalance);

        vm.stopBroadcast();
    }
}
