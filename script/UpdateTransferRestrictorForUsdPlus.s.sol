// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {console2} from "forge-std/console2.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {ITransferRestrictor} from "../src/ITransferRestrictor.sol";
import {UsdPlus} from "../src/UsdPlus.sol";

contract UpdateTransferRestrictorForUsdPlus is Script {
    using stdJson for string;

    /**
     * @notice Script to update the TransferRestrictor address in Upgraded UsdPlus
     * @dev Prerequisites:
     *      1. This script must be run AFTER:
     *         - TRANSFER_RESTRICTOR is deployed (so its address is available in releases)
     *         - UsdPlus is upgraded
     *
     *      2. Environment Variables:
     *         - PRIVATE_KEY: (for signing transactions)
     *         - RPC_URL: (for connecting to the network)
     *         - ENVIRONMENT: Target environment (e.g., production, staging)
     *
     *      3. Required Files:
     *         - releases/v1.0.0/usdplus.json: Contains UsdPlus address under .deployments.<chainId>
     *         - releases/v1.0.0/transfer_restrictor.json: Contains the new TransferRestrictor address under .deployments.<chainId>
     *
     * @dev Workflow:
     *      1. Loads the deployed address of UsdPlus from releases/v1.0.0/usdplus.json
     *      2. Loads the new TransferRestrictor address from releases/v1.0.0/transfer_restrictor.json
     *      3. Checks the current TransferRestrictor address in UsdPlus
     *      4. If the current address matches the new TransferRestrictor, do nothing
     *      5. Otherwise, updates UsdPlus to use the new TransferRestrictor
     * @dev Run:
     *      forge script script/UpdateTransferRestrictorForUsdPlus.s.sol:UpdateTransferRestrictorForUsdPlus \
     *      --rpc-url $RPC_URL \
     *      --private-key $PRIVATE_KEY \
     *      --broadcast
     */
    function run() external {
        // Get environment variables
        string memory environment = vm.envString("ENVIRONMENT");
        string memory chainId = vm.toString(block.chainid);

        // Construct the release config path: releases/v1.0.0/$ENVIRONMENT/UsdPlus.json
        string memory usdPlusPath = string.concat("releases/v1.0.0/usdplus.json");
        string memory usdPlusJson = vm.readFile(usdPlusPath);
        string memory usdPlusSelector = string.concat(".deployments.", environment, ".", chainId);
        address usdPlusAddress = getAddressFromJson(usdPlusJson, usdPlusSelector);

        // get the new TransferRestrictor address from release_v1.0.0/<environment>/<chainId>.json
        string memory transferRestrictorPath = string.concat("releases/v1.0.0/transfer_restrictor.json");
        string memory transferRestrictorJson = vm.readFile(transferRestrictorPath);
        string memory transferRestrictorSelector = string.concat(".deployments.", environment, ".", chainId);
        address newTransferRestrictorAddress = getAddressFromJson(transferRestrictorJson, transferRestrictorSelector);

        UsdPlus usdplus = UsdPlus(usdPlusAddress);
        ITransferRestrictor currentTransferRestrictor = usdplus.transferRestrictor();

        if (address(currentTransferRestrictor) != newTransferRestrictorAddress) {
            usdplus.setTransferRestrictor(ITransferRestrictor(newTransferRestrictorAddress));
            console2.log("TransferRestrictor updated successfully to %s", newTransferRestrictorAddress);
        } else {
            console2.log("TransferRestrictor is already up to date. No action needed.");
        }
    }

    function getAddressFromJson(string memory json, string memory selector) internal pure returns (address) {
        try vm.parseJsonAddress(json, selector) returns (address addr) {
            return addr;
        } catch {
            revert(string.concat("Failed to parse address from JSON: ", selector));
        }
    }
}
