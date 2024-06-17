// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {TransferRestrictor} from "../src/TransferRestrictor.sol";
import {UsdPlus} from "../src/UsdPlus.sol";
import {WrappedUsdPlus} from "../src/WrappedUsdPlus.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployTokenOnly is Script {
    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address treasury = vm.envAddress("TREASURY");

        console.log("deployer: %s", deployer);

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        /// ------------------ usd+ ------------------

        TransferRestrictor transferRestrictor = new TransferRestrictor(deployer);

        UsdPlus usdplusImpl = new UsdPlus();
        UsdPlus usdplus = UsdPlus(
            address(
                new ERC1967Proxy(
                    address(usdplusImpl), abi.encodeCall(UsdPlus.initialize, (treasury, transferRestrictor, deployer))
                )
            )
        );

        WrappedUsdPlus wrappedusdplusImpl = new WrappedUsdPlus();
        WrappedUsdPlus wrappedusdplus = WrappedUsdPlus(
            address(
                new ERC1967Proxy(
                    address(wrappedusdplusImpl), abi.encodeCall(WrappedUsdPlus.initialize, (address(usdplus), deployer))
                )
            )
        );

        vm.stopBroadcast();
    }
}
