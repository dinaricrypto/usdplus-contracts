// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {IKintoWallet} from "kinto-contracts-helpers/interfaces/IKintoWallet.sol";
import {ISponsorPaymaster} from "kinto-contracts-helpers/interfaces/ISponsorPaymaster.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "kinto-contracts-helpers/EntryPointHelper.sol";

contract SendTokens is Script, EntryPointHelper {
    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address owner = vm.envAddress("OWNER");
        IEntryPoint _entryPoint = IEntryPoint(vm.envAddress("ENTRYPOINT"));
        ISponsorPaymaster _sponsorPaymaster = ISponsorPaymaster(vm.envAddress("SPONSOR_PAYMASTER"));

        console.log("deployer: %s", deployer);
        console.log("owner: %s", owner);

        address token = 0x05DC0010C9902EcF6CBc921c6A4bd971c69E5A2E;
        address targetAccount = address(0);
        uint256 sendAmount = 0;

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        // Note: Fails due to SenderKYCRequired
        _handleOps(
            _entryPoint,
            abi.encodeCall(IERC20.transfer, (targetAccount, sendAmount)),
            owner,
            token,
            address(_sponsorPaymaster),
            deployerPrivateKey
        );

        vm.stopBroadcast();
    }
}
