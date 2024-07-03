// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {UnityOracle} from "../../src/mocks/UnityOracle.sol";

import {IKintoWalletFactory} from "kinto-contracts-helpers/interfaces/IKintoWalletFactory.sol";

contract DeployUnityOracle is Script {
    IKintoWalletFactory constant WALLET_FACTORY = IKintoWalletFactory(0x8a4720488CA32f1223ccFE5A087e250fE3BC5D75);

    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address owner = vm.envAddress("OWNER");
        string memory environmentName = vm.envString("ENVIRONMENT");

        console.log("deployer: %s", deployer);
        console.log("owner: %s", owner);

        string memory version = "0.2.1";

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        WALLET_FACTORY.deployContract(
            owner,
            0,
            type(UnityOracle).creationCode,
            keccak256(abi.encode(string.concat("UnityOracle", environmentName, version)))
        );

        vm.stopBroadcast();
    }
}
