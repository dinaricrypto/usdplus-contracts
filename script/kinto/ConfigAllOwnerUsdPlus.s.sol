// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {TransferRestrictor} from "../../src/TransferRestrictor.sol";
import {UsdPlus} from "../../src/UsdPlus.sol";
import {IKintoWallet} from "./external/IKintoWallet.sol";

import "./EntryPointHelper.sol";
import "./external/test/AASetup.sol";

// gives owner all permissions to TransferRestrictor and UsdPlus
contract ConfigAllOwnerUsdPlus is AASetup, EntryPointHelper {
    struct Config {
        TransferRestrictor transferRestrictor;
        UsdPlus usdplus;
    }

    IEntryPoint _entryPoint;

    function setUp() public {
        (, _entryPoint,,) = _checkAccountAbstraction();
        console.log("All AA setup is correct");
    }

    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address owner = vm.envAddress("OWNER");

        Config memory cfg = Config({
            transferRestrictor: TransferRestrictor(vm.envAddress("TRANSFER_RESTRICTOR")),
            usdplus: UsdPlus(vm.envAddress("USDPLUS"))
        });

        console.log("deployer: %s", deployer);
        console.log("owner: %s", owner);

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        // authorize kinto wallet to call contracts
        address[] memory apps = new address[](2);
        apps[0] = address(cfg.transferRestrictor);
        apps[1] = address(cfg.usdplus);

        bool[] memory flags = new bool[](2);
        flags[0] = true;
        flags[1] = true;

        _handleOps(
            _entryPoint,
            abi.encodeWithSelector(IKintoWallet.whitelistApp.selector, apps, flags),
            owner,
            owner,
            deployerPrivateKey
        );

        // permissions to call
        // - restrict(address account)
        // - unrestrict(address account)
        cfg.transferRestrictor.grantRole(cfg.transferRestrictor.RESTRICTOR_ROLE(), owner);

        // permissions to call
        // - rebaseAdd(uint128 value)
        // - rebaseMul(uint128 factor)
        cfg.usdplus.grantRole(cfg.usdplus.OPERATOR_ROLE(), owner);
        // permissions to call
        // - mint(address to, uint256 value)
        // - burn(address from, uint256 value)
        // - burn(uint256 value)
        cfg.usdplus.setIssuerLimits(owner, type(uint256).max, type(uint256).max);

        vm.stopBroadcast();
    }
}
