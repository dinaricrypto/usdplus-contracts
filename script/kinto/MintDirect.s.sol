// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {UsdPlus} from "../../src/UsdPlus.sol";
import {IERC7281Min} from "../../src/ERC7281/IERC7281Min.sol";
import {IKintoWallet} from "./external/IKintoWallet.sol";
import {ISponsorPaymaster} from "./external/ISponsorPaymaster.sol";

import "./EntryPointHelper.sol";

contract MintDirect is Script, EntryPointHelper {
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

        address target = 0x26E508D5d63499e549D958B42c4e2630272Ce2a2;
        uint256 amount = 100_000 * 10 ** 6;

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        // usdplus.mint(deployer, 10 ** 6);
        _handleOps(
            _entryPoint,
            abi.encodeCall(IERC7281Min.mint, (target, amount)),
            owner,
            address(usdplus),
            address(_sponsorPaymaster),
            deployerPrivateKey
        );

        // usdplus.burn(deployer, 10 ** 6);
        // _handleOps(
        //     _entryPoint,
        //     abi.encodeCall(IERC7281Min.burn, (owner, 10 ** 6)),
        //     owner,
        //     address(usdplus),
        //     address(_sponsorPaymaster),
        //     deployerPrivateKey
        // );

        vm.stopBroadcast();
    }
}
