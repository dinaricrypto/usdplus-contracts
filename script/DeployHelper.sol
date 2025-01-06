// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {stdJson} from "forge-std/StdJson.sol";

contract DeployHelper is Script {
    using stdJson for string;

    error MissingRequiredEnvVar(string name);
    error InvalidAddress(string name, address value);
    error JsonParsingError();
    error InitMethodNotFound();
    error InvalidAbiFormat();

    struct InitializeParams {
        address initialTreasury;
        address initialTransferRestrictor;
        address initialOwner;
        address upgrader;
        string version;
    }

    function getInitializeParams() public view returns (InitializeParams memory) {
        InitializeParams memory params;

        // Get required environment variables
        params.initialTreasury = _getEnvAddress("TREASURY_ADDRESS");
        params.initialTransferRestrictor = _getEnvAddress("TRANSFER_RESTRICTOR");
        params.initialOwner = _getEnvAddress("OWNER_ADDRESS");
        params.upgrader = _getEnvAddress("UPGRADER_ADDRESS");
        params.version = vm.envString("VERSION");

        // Validate addresses
        _validateAddress("TREASURY_ADDRESS", params.initialTreasury);
        _validateAddress("TRANSFER_RESTRICTOR", params.initialTransferRestrictor);
        _validateAddress("OWNER_ADDRESS", params.initialOwner);
        _validateAddress("UPGRADER_ADDRESS", params.upgrader);

        // Log the parameters
        console2.log("Initialize Parameters:");
        console2.log("- Initial Treasury:", params.initialTreasury);
        console2.log("- Initial Transfer Restrictor:", params.initialTransferRestrictor);
        console2.log("- Initial Owner:", params.initialOwner);
        console2.log("- Upgrader:", params.upgrader);
        console2.log("- Version:", params.version);

        return params;
    }

    function getInitializeCalldata(InitializeParams memory params) public pure returns (bytes memory) {
        return abi.encodeWithSignature(
            "initialize(address,address,address,address,string)",
            params.initialTreasury,
            params.initialTransferRestrictor,
            params.initialOwner,
            params.upgrader,
            params.version
        );
    }


    function getReinitializeCalldata(InitializeParams memory params) public pure returns (bytes memory) {
        return abi.encodeWithSignature("reinitialize(address, string)", params.upgrader, params.version);
    }

    function getContractAbi(string memory contractName) public view returns (string memory) {
        string memory root = vm.projectRoot();
        string memory jsonPath = string.concat(root, "/out/", contractName, ".sol/", contractName, ".json");
        string memory json = vm.readFile(jsonPath);

        return json;
    }

    function _getEnvAddress(string memory name) internal view returns (address) {
        try vm.envAddress(name) returns (address value) {
            return value;
        } catch {
            revert MissingRequiredEnvVar(name);
        }
    }

    function _validateAddress(string memory name, address value) internal pure {
        if (value == address(0)) {
            revert InvalidAddress(name, value);
        }
    }

    function _bytesToString(bytes memory input) internal pure returns (string memory) {
        if (input.length == 0) {
            return "";
        }

        return string(input);
    }
}
