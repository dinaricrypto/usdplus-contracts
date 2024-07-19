// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {TransferRestrictor} from "../../src/TransferRestrictor.sol";
import {UsdPlus} from "../../src/UsdPlus.sol";
import {UsdPlusMinter} from "../../src/UsdPlusMinter.sol";
import {UsdPlusRedeemer} from "../../src/UsdPlusRedeemer.sol";
import {IKintoWallet} from "kinto-contracts-helpers/interfaces/IKintoWallet.sol";
import {ISponsorPaymaster} from "kinto-contracts-helpers/interfaces/ISponsorPaymaster.sol";
import {IAccessControlDefaultAdminRules} from
    "openzeppelin-contracts/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";

import "kinto-contracts-helpers/EntryPointHelper.sol";

// gives owner all permissions to TransferRestrictor and UsdPlus
contract MigrateOwner is Script, EntryPointHelper {
    struct Config {
        TransferRestrictor transferRestrictor;
        UsdPlus usdplus;
        UsdPlusMinter minter;
        UsdPlusRedeemer redeemer;
    }

    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address kintoWallet = vm.envAddress("KINTO_WALLET");
        IEntryPoint _entryPoint = IEntryPoint(vm.envAddress("ENTRYPOINT"));
        ISponsorPaymaster _sponsorPaymaster = ISponsorPaymaster(vm.envAddress("SPONSOR_PAYMASTER"));

        Config memory cfg = Config({
            transferRestrictor: TransferRestrictor(vm.envAddress("TRANSFER_RESTRICTOR")),
            usdplus: UsdPlus(vm.envAddress("USDPLUS")),
            minter: UsdPlusMinter(vm.envAddress("MINTER")),
            redeemer: UsdPlusRedeemer(vm.envAddress("REDEEMER"))
        });

        console.log("deployer: %s", deployer);
        console.log("kinto wallet: %s", kintoWallet);

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        _handleOps(
            _entryPoint,
            abi.encodeCall(IAccessControlDefaultAdminRules.beginDefaultAdminTransfer, (deployer)),
            kintoWallet,
            address(cfg.transferRestrictor),
            address(_sponsorPaymaster),
            deployerPrivateKey
        );
        cfg.transferRestrictor.acceptDefaultAdminTransfer();

        _handleOps(
            _entryPoint,
            abi.encodeCall(IAccessControlDefaultAdminRules.beginDefaultAdminTransfer, (deployer)),
            kintoWallet,
            address(cfg.usdplus),
            address(_sponsorPaymaster),
            deployerPrivateKey
        );
        cfg.usdplus.acceptDefaultAdminTransfer();

        _handleOps(
            _entryPoint,
            abi.encodeCall(IAccessControlDefaultAdminRules.beginDefaultAdminTransfer, (deployer)),
            kintoWallet,
            address(cfg.minter),
            address(_sponsorPaymaster),
            deployerPrivateKey
        );
        cfg.minter.acceptDefaultAdminTransfer();

        _handleOps(
            _entryPoint,
            abi.encodeCall(IAccessControlDefaultAdminRules.beginDefaultAdminTransfer, (deployer)),
            kintoWallet,
            address(cfg.redeemer),
            address(_sponsorPaymaster),
            deployerPrivateKey
        );
        cfg.redeemer.acceptDefaultAdminTransfer();

        vm.stopBroadcast();
    }
}
