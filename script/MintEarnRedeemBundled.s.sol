// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import {ERC20Mock} from "../src/mocks/ERC20Mock.sol";
import {UsdPlus} from "../src/UsdPlus.sol";
import {UsdPlusPlus} from "../src/UsdPlusPlus.sol";
import {Minter} from "../src/Minter.sol";
import {Redeemer} from "../src/Redeemer.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract MintEarnRedeemBundled is Script {
    struct DeployConfig {
        ERC20Mock usdc;
        UsdPlus usdPlus;
        UsdPlusPlus usdPlusPlus;
        Minter minter;
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
            usdPlusPlus: UsdPlusPlus(vm.envAddress("USDPLUSPLUS")),
            minter: Minter(vm.envAddress("MINTER")),
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

        // mint usd+ and stake for usd++
        cfg.usdc.approve(address(cfg.minter), amount);
        cfg.minter.issueAndDeposit(user, cfg.usdc, amount);
        uint256 usdplusplusBalance = cfg.usdPlusPlus.balanceOf(user);
        console.log("user %s USD++", usdplusplusBalance);

        vm.stopBroadcast();

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        // yield 1% usd+ to usd++
        cfg.usdPlus.mint(address(cfg.usdPlusPlus), amount / 100);

        vm.stopBroadcast();

        // send txs as user
        vm.startBroadcast(userPrivateKey);

        // unstake usd+ and redeem for usdc
        // cfg.usdPlus.approve(address(cfg.redeemer), usdplusBalanceAfter);
        uint256 ticket = cfg.redeemer.redeemAndRequest(user, user, cfg.usdc, usdplusplusBalance);

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
