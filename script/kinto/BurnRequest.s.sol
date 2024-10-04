// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {UsdPlusRedeemer} from "../../src/UsdPlusRedeemer.sol";
import {IKintoWallet} from "kinto-contracts-helpers/interfaces/IKintoWallet.sol";
import {ISponsorPaymaster} from "kinto-contracts-helpers/interfaces/ISponsorPaymaster.sol";

import "kinto-contracts-helpers/EntryPointHelper.sol";

contract BurnRequest is Script, EntryPointHelper {
    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY_STAGE");
        address deployer = vm.addr(deployerPrivateKey);
        address owner = vm.envAddress("KINTO_WALLET");
        IEntryPoint _entryPoint = IEntryPoint(vm.envAddress("ENTRYPOINT"));
        ISponsorPaymaster _sponsorPaymaster = ISponsorPaymaster(vm.envAddress("SPONSOR_PAYMASTER"));
        UsdPlusRedeemer redeemer = UsdPlusRedeemer(vm.envAddress("REDEEMER"));

        console.log("deployer: %s", deployer);
        console.log("owner: %s", owner);

        uint256 ticket = 32;

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        _handleOps(
            _entryPoint,
            abi.encodeCall(UsdPlusRedeemer.burnRequest, (ticket)),
            owner,
            address(redeemer),
            address(_sponsorPaymaster),
            deployerPrivateKey
        );

        vm.stopBroadcast();
    }
}
