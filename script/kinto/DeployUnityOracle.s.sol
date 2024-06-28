// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {UnityOracle} from "../../src/mocks/UnityOracle.sol";

contract DeployUnityOracle is Script {
    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        string memory environmentName = vm.envString("ENVIRONMENT");

        console.log("deployer: %s", deployer);

        string memory version = "0.2.1";

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        UnityOracle unityOracle = new UnityOracle{salt: keccak256(abi.encode(string.concat("UnityOracle", environmentName, version)))}();
        console.log("unityOracle: %s", address(unityOracle));

        vm.stopBroadcast();
    }
}
