// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {UsdPlusRedeemer} from "../../src/UsdPlusRedeemer.sol";
import {IKintoWallet} from "kinto-contracts-helpers/interfaces/IKintoWallet.sol";
import {ISponsorPaymaster} from "kinto-contracts-helpers/interfaces/ISponsorPaymaster.sol";
import {ERC20} from "solady/src/tokens/ERC20.sol";

import "kinto-contracts-helpers/EntryPointHelper.sol";

contract FillRedeem is Script, EntryPointHelper {
    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address owner = vm.envAddress("OWNER");
        IEntryPoint _entryPoint = IEntryPoint(vm.envAddress("ENTRYPOINT"));
        ISponsorPaymaster _sponsorPaymaster = ISponsorPaymaster(vm.envAddress("SPONSOR_PAYMASTER"));
        UsdPlusRedeemer redeemer = UsdPlusRedeemer(vm.envAddress("REDEEMER"));
        ERC20 usdc = ERC20(vm.envAddress("USDC"));

        console.log("deployer: %s", deployer);
        console.log("owner: %s", owner);

        uint256 ticket = 1;
        uint256 fillAmount = 560000000;

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        // approve
        _handleOps(
            _entryPoint,
            abi.encodeCall(ERC20.approve, (address(redeemer), fillAmount)),
            owner,
            address(usdc),
            address(_sponsorPaymaster),
            deployerPrivateKey
        );

        _handleOps(
            _entryPoint,
            abi.encodeCall(UsdPlusRedeemer.fulfill, (ticket)),
            owner,
            address(redeemer),
            address(_sponsorPaymaster),
            deployerPrivateKey
        );

        vm.stopBroadcast();
    }
}
