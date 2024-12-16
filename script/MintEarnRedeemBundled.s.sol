// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {ERC20Mock} from "../src/mocks/ERC20Mock.sol";
import {UsdPlus} from "../src/UsdPlus.sol";
import {WrappedUsdPlus} from "../src/WrappedUsdPlus.sol";
import {UsdPlusMinter} from "../src/UsdPlusMinter.sol";
import {UsdPlusRedeemer, IUsdPlusRedeemer} from "../src/UsdPlusRedeemer.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract MintEarnRedeemBundled is Script {
    struct DeployConfig {
        ERC20Mock usdc;
        UsdPlus usdPlus;
        WrappedUsdPlus wrappedUsdplus;
        UsdPlusMinter minter;
        UsdPlusRedeemer redeemer;
    }

    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOY_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        uint256 userPrivateKey = vm.envUint("USER_KEY");
        address user = vm.addr(userPrivateKey);

        DeployConfig memory cfg = DeployConfig({
            usdc: ERC20Mock(vm.envAddress("USDC")),
            usdPlus: UsdPlus(vm.envAddress("USDPLUS")),
            wrappedUsdplus: WrappedUsdPlus(vm.envAddress("WRAPPEDUSDPLUS")),
            minter: UsdPlusMinter(vm.envAddress("MINTER")),
            redeemer: UsdPlusRedeemer(vm.envAddress("REDEEMER"))
        });

        console.log("deployer: %s", deployer);

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        // mint payment token
        uint256 amount = 10_000 * 10 ** cfg.usdc.decimals();
        cfg.usdc.mint(deployer, amount);
        cfg.usdc.mint(user, amount);
        console.log("user %s USDC", cfg.usdc.balanceOf(user));
        console.log("reserve %s USDC", cfg.usdc.balanceOf(deployer));

        vm.stopBroadcast();

        // send txs as user
        vm.startBroadcast(userPrivateKey);

        // mint usd+ and stake for stUSD+
        cfg.usdc.approve(address(cfg.minter), amount);
        cfg.minter.deposit(cfg.usdc, amount, user, amount);
        uint256 usdplusBalance = cfg.usdPlus.balanceOf(user);
        console.log("user %s USD+", usdplusBalance);

        vm.stopBroadcast();

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        // yield 1% usd+ to stUSD+
        cfg.usdPlus.rebaseAdd(uint128(amount / 100));
        usdplusBalance = cfg.usdPlus.balanceOf(user);
        console.log("user %s USD+", usdplusBalance);

        vm.stopBroadcast();

        // send txs as user
        vm.startBroadcast(userPrivateKey);

        // unstake usd+ and redeem for usdc
        // cfg.usdPlus.approve(address(cfg.redeemer), usdplusBalanceAfter);
        uint256 ticket = cfg.redeemer.requestRedeem(cfg.usdc, usdplusBalance, user, user, usdplusBalance);

        vm.stopBroadcast();

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        // fulfill redemption request
        IUsdPlusRedeemer.Request memory request = cfg.redeemer.requests(ticket);
        cfg.usdc.approve(address(cfg.redeemer), request.paymentTokenAmount);
        cfg.redeemer.fulfill(ticket);
        uint256 usdcBalance = cfg.usdc.balanceOf(user);
        console.log("user %s USDC", usdcBalance);

        vm.stopBroadcast();
    }
}
