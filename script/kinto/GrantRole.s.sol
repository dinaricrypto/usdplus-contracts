// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";

import {TransferRestrictor} from "../../src/TransferRestrictor.sol";

contract GrantRole is Script {
    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        TransferRestrictor targetContract = TransferRestrictor(vm.envAddress("TRANSFER_RESTRICTOR_DSHARES"));

        console.log("deployer: %s", deployer);

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        targetContract.grantRole(targetContract.RESTRICTOR_ROLE(), 0x2246B6949990ceef49343Fe5c55A17C75Ab212ee);

        vm.stopBroadcast();
    }
}
