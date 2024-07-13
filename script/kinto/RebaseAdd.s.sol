// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {UsdPlus} from "../../src/UsdPlus.sol";
import {IKintoWallet} from "kinto-contracts-helpers/interfaces/IKintoWallet.sol";
import {ISponsorPaymaster} from "kinto-contracts-helpers/interfaces/ISponsorPaymaster.sol";

import "kinto-contracts-helpers/EntryPointHelper.sol";

contract RebaseAdd is Script, EntryPointHelper {
    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address owner = vm.envAddress("OWNER");
        IEntryPoint _entryPoint = IEntryPoint(vm.envAddress("ENTRYPOINT"));
        ISponsorPaymaster _sponsorPaymaster = ISponsorPaymaster(vm.envAddress("SPONSOR_PAYMASTER"));
        UsdPlus usdplus = UsdPlus(vm.envAddress("USDPLUS"));

        console.log("deployer: %s", deployer);
        console.log("owner: %s", owner);

        uint128 rebaseAddAmount = 16737976266;

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        _handleOps(
            _entryPoint,
            abi.encodeCall(UsdPlus.rebaseAdd, (rebaseAddAmount)),
            owner,
            address(usdplus),
            address(_sponsorPaymaster),
            deployerPrivateKey
        );

        vm.stopBroadcast();
    }
}
