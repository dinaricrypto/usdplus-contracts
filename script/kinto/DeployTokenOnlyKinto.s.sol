// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";

import "account-abstraction/interfaces/IEntryPoint.sol";

import "./external/IKintoWallet.sol";
import "./external/IKintoWalletFactory.sol";
import "./external/ISponsorPaymaster.sol";

import "./external/AASetup.sol";
import "./external/UserOp.sol";

import {TransferRestrictor} from "../../src/TransferRestrictor.sol";
import {UsdPlus} from "../../src/UsdPlus.sol";
import {WrappedUsdPlus} from "../../src/WrappedUsdPlus.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployTokenOnlyKinto is AASetup, UserOp {
    IEntryPoint _entryPoint;
    IKintoWalletFactory _walletFactory;
    ISponsorPaymaster _sponsorPaymaster;
    IKintoWallet _newWallet;

    function setUp() public {
        (, _entryPoint, _walletFactory, _sponsorPaymaster) = _checkAccountAbstraction();
        console.log("All AA setup is correct");
    }

    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address treasury = vm.envAddress("TREASURY");

        console.log("Deployer is", deployer);

        address newWallet = _walletFactory.getAddress(deployer, deployer, bytes32(0));
        if (!isContract(newWallet)) {
            console.log("No wallet found with owner", deployer, "at", newWallet);
            vm.broadcast(deployerPrivateKey);
            address ikw = address(_walletFactory.createAccount(deployer, deployer, 0));
            console.log("- A new wallet has been created", ikw);
        }
        _newWallet = IKintoWallet(newWallet);

        // // Counter contract
        // address computed =
        //     _walletFactory.getContractAddress(bytes32(0), keccak256(abi.encodePacked(type(Counter).creationCode)));
        // if (!isContract(computed)) {
        //     vm.broadcast(deployerPrivateKey);
        //     address created = _walletFactory.deployContract(
        //         deployerPublicKey, 0, abi.encodePacked(type(Counter).creationCode), bytes32(0)
        //     );
        //     console.log("Counter contract deployed at", created);
        // } else {
        //     console.log("Counter already deployed at", computed);
        // }

        // /// ------------------ usd+ ------------------

        // TransferRestrictor transferRestrictor = new TransferRestrictor(deployer);

        // UsdPlus usdplusImpl = new UsdPlus();
        // UsdPlus usdplus = UsdPlus(
        //     address(
        //         new ERC1967Proxy(
        //             address(usdplusImpl), abi.encodeCall(UsdPlus.initialize, (treasury, transferRestrictor, deployer))
        //         )
        //     )
        // );

        // WrappedUsdPlus wrappedusdplusImpl = new WrappedUsdPlus();
        // WrappedUsdPlus wrappedusdplus = WrappedUsdPlus(
        //     address(
        //         new ERC1967Proxy(
        //             address(wrappedusdplusImpl), abi.encodeCall(WrappedUsdPlus.initialize, (address(usdplus), deployer))
        //         )
        //     )
        // );

    }
}
