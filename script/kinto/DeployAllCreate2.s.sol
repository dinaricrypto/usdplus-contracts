// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {TransferRestrictor} from "../../src/TransferRestrictor.sol";
import {UsdPlus} from "../../src/UsdPlus.sol";
import {WrappedUsdPlus} from "../../src/WrappedUsdPlus.sol";
import {UsdPlusMinter} from "../../src/UsdPlusMinter.sol";
import {UsdPlusRedeemer} from "../../src/UsdPlusRedeemer.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployAllCreate2 is Script {
    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address treasury = vm.envAddress("TREASURY");

        console.log("deployer: %s", deployer);

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        /// ------------------ usd+ ------------------

        TransferRestrictor transferRestrictor = new TransferRestrictor{salt: keccak256("TransferRestrictor")}(deployer);
        console.log("transferRestrictor: %s", address(transferRestrictor));

        UsdPlus usdplusImpl = new UsdPlus{salt: keccak256("UsdPlus1")}();
        UsdPlus usdplus = UsdPlus(
            address(
                new ERC1967Proxy{salt: keccak256("UsdPlusProxy")}(
                    address(usdplusImpl), abi.encodeCall(UsdPlus.initialize, (treasury, transferRestrictor, deployer))
                )
            )
        );
        console.log("usdplus: %s", address(usdplus));

        WrappedUsdPlus wrappedusdplusImpl = new WrappedUsdPlus{salt: keccak256("WrappedUsdPlus1")}();
        WrappedUsdPlus wrappedusdplus = WrappedUsdPlus(
            address(
                new ERC1967Proxy{salt: keccak256("WrappedUsdPlusProxy")}(
                    address(wrappedusdplusImpl), abi.encodeCall(WrappedUsdPlus.initialize, (address(usdplus), deployer))
                )
            )
        );
        console.log("wrappedusdplus: %s", address(wrappedusdplus));

        /// ------------------ usd+ minter/redeemer ------------------

        UsdPlusMinter minterImpl = new UsdPlusMinter{salt: keccak256("UsdPlusMinter0.2.1")}();
        UsdPlusMinter minter = UsdPlusMinter(
            address(
                new ERC1967Proxy{salt: keccak256("UsdPlusMinterProxy0.2")}(
                    address(minterImpl),
                    abi.encodeCall(UsdPlusMinter.initialize, (address(usdplus), treasury, deployer))
                )
            )
        );
        console.log("minter: %s", address(minter));

        UsdPlusRedeemer redeemerImpl = new UsdPlusRedeemer{salt: keccak256("UsdPlusRedeemer0.2.1")}();
        UsdPlusRedeemer redeemer = UsdPlusRedeemer(
            address(
                new ERC1967Proxy{salt: keccak256("UsdPlusRedeemerProxy0.2")}(
                    address(redeemerImpl), abi.encodeCall(UsdPlusRedeemer.initialize, (address(usdplus), deployer))
                )
            )
        );
        console.log("redeemer: %s", address(redeemer));

        vm.stopBroadcast();
    }
}
