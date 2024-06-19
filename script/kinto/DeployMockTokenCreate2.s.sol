// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {ERC20Mock} from "../../src/mocks/ERC20Mock.sol";

contract DeployMockTokenCreate2 is Script {
    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("deployer: %s", deployer);

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        ERC20Mock mockUSDC = new ERC20Mock{salt: keccak256("MockUSDC")}("USD Coin - Dinari", "USDC", 6, deployer);
        console.log("mockUSDC: %s", address(mockUSDC));

        vm.stopBroadcast();
    }
}
