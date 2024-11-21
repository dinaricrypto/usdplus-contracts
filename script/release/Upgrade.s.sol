// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {UsdPlus} from "../../src/UsdPlus.sol";
import {WrappedUsdPlus} from "../../src/WrappedUsdPlus.sol";
import {UsdPlusMinter} from "../../src/UsdPlusMinter.sol";
import {UsdPlusRedeemer} from "../../src/UsdPlusRedeemer.sol";

contract Upgrade is Script {
    struct ExistingContracts {
        UsdPlus usdplus;
        WrappedUsdPlus wrappedusdplus;
        UsdPlusMinter minter;
        UsdPlusRedeemer redeemer;
    }

    function run() external {
        // Load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // TODO: make salt from version
        bytes32 salt = keccak256(abi.encodePacked(deployer));

        ExistingContracts memory existing = ExistingContracts({
            usdplus: UsdPlus(vm.envAddress("USDPLUS")),
            wrappedusdplus: WrappedUsdPlus(vm.envAddress("WRAPPEDUSDPLUS")),
            minter: UsdPlusMinter(vm.envAddress("USDPLUSMINTER")),
            redeemer: UsdPlusRedeemer(vm.envAddress("USDPLUSREDEEMER"))
        });

        console.log("deployer: %s", deployer);

        // Send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        /// ------------------ usd+ ------------------

        UsdPlus usdplusImpl = new UsdPlus{salt: salt}();

        existing.usdplus.upgradeToAndCall(address(usdplusImpl), "");

        WrappedUsdPlus wrappedusdplusImpl = new WrappedUsdPlus{salt: salt}();

        existing.wrappedusdplus.upgradeToAndCall(address(wrappedusdplusImpl), "");

        /// ------------------ usd+ minter/redeemer ------------------

        UsdPlusMinter minterImpl = new UsdPlusMinter{salt: salt}();

        existing.minter.upgradeToAndCall(address(minterImpl), "");

        UsdPlusRedeemer redeemerImpl = new UsdPlusRedeemer{salt: salt}();

        existing.redeemer.upgradeToAndCall(address(redeemerImpl), "");

        vm.stopBroadcast();
    }
}
