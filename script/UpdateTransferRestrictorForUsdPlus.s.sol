// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {console2} from "forge-std/console2.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {JsonUtils} from "./utils/JsonUtils.sol";
import {ITransferRestrictor} from "../src/ITransferRestrictor.sol";
import {UsdPlus} from "../src/UsdPlus.sol";

contract UpdateTransferRestrictorForUsdPlus is Script {
    using stdJson for string;

    /**
     * @notice Script to update the TransferRestrictor address in Upgraded UsdPlus
     * @dev Prerequisites:
     *      1. This script must be run AFTER:
     *         - TRANSFER_RESTRICTOR is deployed (so its address is available in release_config)
     *         - UsdPlus is upgraded
     *
     *      2. Environment Variables:
     *         - PRIVATE_KEY: (for signing transactions)
     *         - RPC_URL: (for connecting to the network)
     *         - ENVIRONMENT: Target environment (e.g., production, staging)
     *
     *      3. Required Files:
     *         - releases/v1.0.0/usdplus.json: Contains UsdPlus address under .deployments.<chainId>
     *         - release_config/<environment>/<chainId>.json: Contains the TransferRestrictor address under .UsdPlus.transferRestrictor
     *
     * @dev Workflow:
     *      1. Loads the deployed address of UsdPlus from releases/v1.0.0/<environment>/UsdPlus.json under .deployments.<chainId>
     *      2. Loads the new TransferRestrictor address from release_config under .UsdPlus.transferRestrictor
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
        string memory releasePath = string.concat("releases/v1.0.0/usdplus.json");

        // Load the release JSON
        string memory releaseJson = vm.readFile(releasePath);

        // Construct the selector for the UsdPlus address
        string memory selectorString = string.concat(".deployments.", environment, ".", chainId);
        address usdPlusAddress = JsonUtils.getAddressFromJson(vm, releaseJson, selectorString);

        require(usdPlusAddress != address(0), "UsdPlus address not found in release config");

        // Load the new TransferRestrictor address from release_config under .UsdPlus.transferRestrictor
        string memory configPath = string.concat("release_config/", environment, "/", chainId, ".json");
        string memory configJson = vm.readFile(configPath);
        address newTransferRestrictorAddress = _getAddressFromConfig(configJson, "UsdPlus", "transferRestrictor");

        require(newTransferRestrictorAddress != address(0), "TransferRestrictor address not found in config");

        console2.log("UsdPlus address: %s", usdPlusAddress);
        console2.log("New TransferRestrictor address (from config): %s", newTransferRestrictorAddress);

        // Check current TransferRestrictor in UsdPlus
        UsdPlus usdplus = UsdPlus(usdPlusAddress);
        ITransferRestrictor currentTransferRestrictor = usdplus.transferRestrictor();

        console2.log("Current TransferRestrictor in UsdPlus: %s", address(currentTransferRestrictor));

        // Compare and update if necessary
        if (address(currentTransferRestrictor) == newTransferRestrictorAddress) {
            console2.log("TransferRestrictor is already up to date. No action needed.");
        } else {
            console2.log("Updating TransferRestrictor in UsdPlus...");
            vm.startBroadcast();
            usdplus.setTransferRestrictor(ITransferRestrictor(newTransferRestrictorAddress));
            vm.stopBroadcast();
            console2.log("TransferRestrictor updated successfully to %s", newTransferRestrictorAddress);

            // Verify the update
            ITransferRestrictor updatedTransferRestrictor = usdplus.transferRestrictor();
            require(
                address(updatedTransferRestrictor) == newTransferRestrictorAddress,
                "TransferRestrictor update verification failed"
            );
            console2.log("Verified: TransferRestrictor in UsdPlus is now %s", address(updatedTransferRestrictor));
        }
    }

    /**
     * @notice Loads an address from the release_config JSON file
     * @param configJson The JSON content of the config file
     * @param contractName The underscore-formatted name of the contract (e.g., "UsdPlus")
     * @param paramName The parameter name (e.g., "transferRestrictor")
     * @return The address from the config
     */
    function _getAddressFromConfig(string memory configJson, string memory contractName, string memory paramName)
        internal
        pure
        returns (address)
    {
        string memory selector = string.concat(".", contractName, ".", paramName);
        return JsonUtils.getAddressFromJson(vm, configJson, selector);
    }
}
