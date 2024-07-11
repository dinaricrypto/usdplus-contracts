// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {TransferRestrictor} from "../../src/TransferRestrictor.sol";
import {UsdPlus} from "../../src/UsdPlus.sol";
import {UsdPlusRedeemer} from "../../src/UsdPlusRedeemer.sol";
import {IKintoWallet} from "kinto-contracts-helpers/interfaces/IKintoWallet.sol";
import {ISponsorPaymaster} from "kinto-contracts-helpers/interfaces/ISponsorPaymaster.sol";
import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";

import "kinto-contracts-helpers/EntryPointHelper.sol";

// gives owner all permissions to TransferRestrictor and UsdPlus
contract ConfigAllOwnerUsdPlus is Script, EntryPointHelper {
    struct Config {
        TransferRestrictor transferRestrictor;
        UsdPlus usdplus;
        UsdPlusRedeemer redeemer;
    }

    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address owner = vm.envAddress("OWNER");
        IEntryPoint _entryPoint = IEntryPoint(vm.envAddress("ENTRYPOINT"));
        ISponsorPaymaster _sponsorPaymaster = ISponsorPaymaster(vm.envAddress("SPONSOR_PAYMASTER"));

        Config memory cfg = Config({
            transferRestrictor: TransferRestrictor(vm.envAddress("TRANSFER_RESTRICTOR")),
            usdplus: UsdPlus(vm.envAddress("USDPLUS")),
            redeemer: UsdPlusRedeemer(vm.envAddress("REDEEMER"))
        });

        console.log("deployer: %s", deployer);
        console.log("owner: %s", owner);

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        // permissions to call
        // - restrict(address account)
        // - unrestrict(address account)
        // cfg.transferRestrictor.grantRole(cfg.transferRestrictor.RESTRICTOR_ROLE(), owner);
        _handleOps(
            _entryPoint,
            abi.encodeWithSelector(IAccessControl.grantRole.selector, cfg.transferRestrictor.RESTRICTOR_ROLE(), owner),
            owner,
            address(cfg.transferRestrictor),
            address(_sponsorPaymaster),
            deployerPrivateKey
        );

        // permissions to call
        // - rebaseAdd(uint128 value)
        // - rebaseMul(uint128 factor)
        // cfg.usdplus.grantRole(cfg.usdplus.OPERATOR_ROLE(), owner);
        _handleOps(
            _entryPoint,
            abi.encodeWithSelector(IAccessControl.grantRole.selector, cfg.usdplus.OPERATOR_ROLE(), owner),
            owner,
            address(cfg.usdplus),
            address(_sponsorPaymaster),
            deployerPrivateKey
        );
        // permissions to call
        // - mint(address to, uint256 value)
        // - burn(address from, uint256 value)
        // - burn(uint256 value)
        // cfg.usdplus.setIssuerLimits(owner, type(uint256).max, type(uint256).max);
        _handleOps(
            _entryPoint,
            abi.encodeWithSelector(UsdPlus.setIssuerLimits.selector, owner, type(uint256).max, type(uint256).max),
            owner,
            address(cfg.usdplus),
            address(_sponsorPaymaster),
            deployerPrivateKey
        );

        // permissions to call
        // - fulfill(uint256 ticket)
        // cfg.redeemer.grantRole(cfg.redeemer.FULFILLER_ROLE(), owner);
        _handleOps(
            _entryPoint,
            abi.encodeWithSelector(IAccessControl.grantRole.selector, cfg.redeemer.FULFILLER_ROLE(), owner),
            owner,
            address(cfg.redeemer),
            address(_sponsorPaymaster),
            deployerPrivateKey
        );

        vm.stopBroadcast();
    }
}
