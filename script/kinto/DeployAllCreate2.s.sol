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
        address owner = vm.envAddress("OWNER");
        address upgrader = vm.envAddress("UPGRADER");
        string memory environmentName = vm.envString("ENVIRONMENT");

        console.log("deployer: %s", deployer);
        console.log("owner: %s", owner);

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        /// ------------------ usd+ ------------------
        TransferRestrictor transferRestrictorImpl = new TransferRestrictor{
            salt: keccak256(abi.encode(string.concat("TransferRestrictor", environmentName, "0.2.1")))
        }();
        TransferRestrictor transferRestrictor = TransferRestrictor(
            address(
                new ERC1967Proxy{
                    salt: keccak256(abi.encode(string.concat("TransferRestrictorProxy", environmentName, "0.2.1")))
                }(address(transferRestrictorImpl), abi.encodeCall(TransferRestrictor.initialize, (owner, upgrader)))
            )
        );
        console.log("transferRestrictorImpl: %s", address(transferRestrictorImpl));
        console.log("transferRestrictor: %s", address(transferRestrictor));

        UsdPlus usdplusImpl =
            new UsdPlus{salt: keccak256(abi.encode(string.concat("UsdPlus", environmentName, "0.2.1")))}();
        UsdPlus usdplus = UsdPlus(
            address(
                new ERC1967Proxy{salt: keccak256(abi.encode(string.concat("UsdPlusProxy", environmentName, "0.2.1")))}(
                    address(usdplusImpl),
                    abi.encodeCall(UsdPlus.initialize, (treasury, transferRestrictor, owner, upgrader))
                )
            )
        );
        console.log("usdplusimpl: %s", address(usdplusImpl));
        console.log("usdplus: %s", address(usdplus));

        WrappedUsdPlus wrappedusdplusImpl =
            new WrappedUsdPlus{salt: keccak256(abi.encode(string.concat("WrappedUsdPlus", environmentName, "0.2.1")))}();
        WrappedUsdPlus wrappedusdplus = WrappedUsdPlus(
            address(
                new ERC1967Proxy{
                    salt: keccak256(abi.encode(string.concat("WrappedUsdPlusProxy", environmentName, "0.2.1")))
                }(
                    address(wrappedusdplusImpl),
                    abi.encodeCall(WrappedUsdPlus.initialize, (address(usdplus), owner, upgrader))
                )
            )
        );
        console.log("wrappedusdplusimpl: %s", address(wrappedusdplusImpl));
        console.log("wrappedusdplus: %s", address(wrappedusdplus));

        /// ------------------ usd+ minter/redeemer ------------------

        UsdPlusMinter minterImpl =
            new UsdPlusMinter{salt: keccak256(abi.encode(string.concat("UsdPlusMinter", environmentName, "0.2.1")))}();
        UsdPlusMinter minter = UsdPlusMinter(
            address(
                new ERC1967Proxy{
                    salt: keccak256(abi.encode(string.concat("UsdPlusMinterProxy", environmentName, "0.2.1")))
                }(
                    address(minterImpl),
                    abi.encodeCall(UsdPlusMinter.initialize, (address(usdplus), treasury, owner, upgrader))
                )
            )
        );
        console.log("minterimpl: %s", address(minterImpl));
        console.log("minter: %s", address(minter));

        UsdPlusRedeemer redeemerImpl = new UsdPlusRedeemer{
            salt: keccak256(abi.encode(string.concat("UsdPlusRedeemer", environmentName, "0.2.1")))
        }();
        UsdPlusRedeemer redeemer = UsdPlusRedeemer(
            address(
                new ERC1967Proxy{
                    salt: keccak256(abi.encode(string.concat("UsdPlusRedeemerProxy", environmentName, "0.2.1")))
                }(
                    address(redeemerImpl),
                    abi.encodeCall(UsdPlusRedeemer.initialize, (address(usdplus), owner, upgrader))
                )
            )
        );
        console.log("redeemerimpl: %s", address(redeemerImpl));
        console.log("redeemer: %s", address(redeemer));

        vm.stopBroadcast();
    }
}
