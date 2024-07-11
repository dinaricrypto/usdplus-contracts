// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {TransferRestrictor} from "../../src/TransferRestrictor.sol";
import {UsdPlus} from "../../src/UsdPlus.sol";
import {UsdPlusMinter} from "../../src/UsdPlusMinter.sol";
import {UsdPlusRedeemer} from "../../src/UsdPlusRedeemer.sol";
// import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "../../src/mocks/ERC20Mock.sol";
import {IKintoWallet} from "kinto-contracts-helpers/interfaces/IKintoWallet.sol";
import {ISponsorPaymaster} from "kinto-contracts-helpers/interfaces/ISponsorPaymaster.sol";

import "kinto-contracts-helpers/EntryPointHelper.sol";

contract ApproveApps is Script, EntryPointHelper {
    struct Config {
        address transferRestrictor;
        address usdplus;
        address minter;
        address redeemer;
        address usdc;
    }

    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address owner = vm.envAddress("OWNER");
        IEntryPoint _entryPoint = IEntryPoint(vm.envAddress("ENTRYPOINT"));
        ISponsorPaymaster _sponsorPaymaster = ISponsorPaymaster(vm.envAddress("SPONSOR_PAYMASTER"));

        Config memory cfg = Config({
            transferRestrictor: vm.envAddress("TRANSFER_RESTRICTOR"),
            usdplus: vm.envAddress("USDPLUS"),
            minter: vm.envAddress("MINTER"),
            redeemer: vm.envAddress("REDEEMER"),
            usdc: vm.envAddress("USDC")
        });

        console.log("deployer: %s", deployer);
        console.log("owner: %s", owner);

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        // authorize kinto wallet to call contracts
        address[] memory apps = new address[](6);
        apps[0] = cfg.transferRestrictor;
        apps[1] = cfg.usdplus;
        apps[2] = cfg.minter;
        apps[3] = cfg.redeemer;
        apps[4] = CREATE2_FACTORY;
        apps[5] = cfg.usdc; //MockUSDC

        bool[] memory flags = new bool[](6);
        flags[0] = true;
        flags[1] = true;
        flags[2] = true;
        flags[3] = true;
        flags[4] = true;
        flags[5] = true;

        // for (uint256 i = 0; i < apps.length; i++) {
        //     uint256 _balance = _sponsorPaymaster.balances(apps[i]);
        //     if (_balance <= 0.0007 ether) {
        //         _sponsorPaymaster.addDepositFor{value: 0.0007 ether }(apps[i]);
        //         console.log("Adding paymaster balance to", apps[i]);
        //     }
        // }
        // Note: Fails due to SenderKYCRequired
        // _sponsorPaymaster.addDepositFor{value: 0.0007 ether}(owner);

        _handleOps(
            _entryPoint,
            abi.encodeWithSelector(IKintoWallet.whitelistApp.selector, apps, flags),
            owner,
            owner,
            address(_sponsorPaymaster),
            deployerPrivateKey
        );

        vm.stopBroadcast();
    }
}