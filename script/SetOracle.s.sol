// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {UsdPlusMinter} from "../src/UsdPlusMinter.sol";
import {UsdPlusRedeemer} from "../src/UsdPlusRedeemer.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract SetOracle is Script {
    function run() external {
        // Load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        UsdPlusMinter minter = UsdPlusMinter(vm.envAddress("MINTER"));
        UsdPlusRedeemer redeemer = UsdPlusRedeemer(vm.envAddress("REDEEMER"));
        AggregatorV3Interface oracle = AggregatorV3Interface(vm.envAddress("ORACLE"));
        IERC20 usdc = IERC20(vm.envAddress("USDC"));

        console.log("deployer: %s", deployer);

        // Send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        minter.setPaymentTokenOracle(usdc, oracle);
        redeemer.setPaymentTokenOracle(usdc, oracle);

        vm.stopBroadcast();
    }
}
