// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import {ERC20Mock} from "../src/mocks/ERC20Mock.sol";
import {UsdPlus} from "../src/UsdPlus.sol";
import {StakedUsdPlus} from "../src/StakedUsdPlus.sol";
import {UsdPlusMinter} from "../src/UsdPlusMinter.sol";
import {Redeemer} from "../src/Redeemer.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract MintEarnRedeem is Script {
    struct DeployConfig {
        ERC20Mock usdc;
        UsdPlus usdPlus;
        StakedUsdPlus stakedUsdplus;
        UsdPlusMinter minter;
        Redeemer redeemer;
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
            stakedUsdplus: StakedUsdPlus(vm.envAddress("STAKEDUSDPLUS")),
            minter: UsdPlusMinter(vm.envAddress("MINTER")),
            redeemer: Redeemer(vm.envAddress("REDEEMER"))
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

        // mint usd+
        cfg.usdc.approve(address(cfg.minter), amount);
        cfg.minter.issue(user, cfg.usdc, amount);
        uint256 usdplusBalance = cfg.usdPlus.balanceOf(user);
        console.log("user %s USD+", usdplusBalance);

        // stake usd+
        cfg.usdPlus.approve(address(cfg.stakedUsdplus), usdplusBalance);
        cfg.stakedUsdplus.deposit(usdplusBalance, user);
        uint256 stakedUsdplusBalance = cfg.stakedUsdplus.balanceOf(user);
        console.log("user %s stUSD+", stakedUsdplusBalance);

        vm.stopBroadcast();

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        // yield 1% usd+
        cfg.usdPlus.mint(address(cfg.stakedUsdplus), amount / 100);

        vm.stopBroadcast();

        // send txs as user
        vm.startBroadcast(userPrivateKey);

        // unstake usd+
        cfg.stakedUsdplus.redeem(stakedUsdplusBalance, user, user);
        uint256 usdplusBalanceAfter = cfg.usdPlus.balanceOf(user);
        console.log("user %s USD+", usdplusBalanceAfter);

        // redeem for usdc
        cfg.usdPlus.approve(address(cfg.redeemer), usdplusBalanceAfter);
        uint256 ticket = cfg.redeemer.request(user, user, cfg.usdc, usdplusBalanceAfter);

        vm.stopBroadcast();

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        // fulfill redemption request
        (,,, uint256 paymentAmount,) = cfg.redeemer.requests(ticket);
        cfg.usdc.approve(address(cfg.redeemer), paymentAmount);
        cfg.redeemer.fulfill(ticket);
        uint256 usdcBalance = cfg.usdc.balanceOf(user);
        console.log("user %s USDC", usdcBalance);

        vm.stopBroadcast();
    }
}
