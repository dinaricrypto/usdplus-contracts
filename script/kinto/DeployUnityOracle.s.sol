// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {UnityOracle} from "../../src/mocks/UnityOracle.sol";

import "kinto-contracts-helpers/EntryPointHelper.sol";

contract DeployUnityOracle is Script, EntryPointHelper {
    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address owner = vm.envAddress("OWNER");
        string memory environmentName = vm.envString("ENVIRONMENT");
        IEntryPoint _entryPoint = IEntryPoint(vm.envAddress("ENTRYPOINT"));

        console.log("deployer: %s", deployer);
        console.log("owner: %s", owner);

        string memory version = "0.2.1";

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        bytes memory _selectorAndParams = abi.encodeWithSignature(
            "deployContract(address,uint256,bytes,bytes32)",
            owner,
            0,
            type(UnityOracle).creationCode,
            keccak256(abi.encode(string.concat("UnityOracle", environmentName, version)))
        );
        _handleOps(_entryPoint, _selectorAndParams, owner, CREATE2_FACTORY, deployerPrivateKey);

        vm.stopBroadcast();
    }
}
