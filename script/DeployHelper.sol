// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {JsonHandler} from "./JsonHandler.sol";

contract DeployHelper is Script {
    using stdJson for string;

    error MissingRequiredParam(string name);
    error InvalidAddress(string name, address value);
    error JsonParsingError();
    error InitMethodNotFound();
    error InvalidAbiFormat();
    error VersionNotFound(string version);
    error EnvironmentNotFound(string environment);

    struct InitializeParams {
        address initialTreasury;
        address initialTransferRestrictor;
        address initialOwner;
        address upgrader;
        string version;
    }

    function getInitializeParams(string memory contractName, string memory version, string memory environment)
        public
        returns (InitializeParams memory)
    {
        string memory root = vm.projectRoot();
        (uint8 majorVersion,) = _parseVersion(version);
        string memory versionPath = string.concat(root, "/releases/v", vm.toString(majorVersion), "/");
        string memory fileName = string.concat(_toLowerSnakeCase(contractName), ".json");
        string memory jsonPath = string.concat(versionPath, fileName);

        // Create directory if it doesn't exist
        vm.createDir(versionPath, true);

        // Try to read existing file
        string memory json = vm.readFile(jsonPath);
        bool isNewFile = bytes(json).length == 0;

        // Get initial parameters (either from env vars or existing json)
        InitializeParams memory params = _getInitialParams(version);

        if (isNewFile) {
            // Create new JSON file with these parameters
            json = JsonHandler._createInitialJson(contractName, version, environment, params);
            vm.writeFile(jsonPath, json);
        } else {
            // Try to read from existing JSON first
            string memory initKey = string.concat(".initialization.", version, ".", environment);
            bool paramsExist = _checkInitParamsExist(json, initKey);

            if (!paramsExist) {
                // Parameters don't exist for this version, update JSON
                json = JsonHandler._updateInitializationParams(json, version, environment, params);
                vm.writeFile(jsonPath, json);
            } else {
                // Read parameters from JSON
                params = _readParamsFromJson(json, initKey, version);
            }
        }

        // Validate addresses
        _validateAddress("treasury", params.initialTreasury);
        _validateAddress("transferRestrictor", params.initialTransferRestrictor);
        _validateAddress("owner", params.initialOwner);
        _validateAddress("upgrader", params.upgrader);

        // Log the parameters
        console2.log("Initialize Parameters:");
        console2.log("- Initial Treasury:", params.initialTreasury);
        console2.log("- Initial Transfer Restrictor:", params.initialTransferRestrictor);
        console2.log("- Initial Owner:", params.initialOwner);
        console2.log("- Upgrader:", params.upgrader);
        console2.log("- Version:", params.version);

        return params;
    }

    function _getInitialParams(string memory version) internal view returns (InitializeParams memory) {
        return InitializeParams({
            initialTreasury: vm.envAddress("TREASURY_ADDRESS"),
            initialTransferRestrictor: vm.envAddress("TRANSFER_RESTRICTOR"),
            initialOwner: vm.envAddress("OWNER_ADDRESS"),
            upgrader: vm.envAddress("UPGRADER_ADDRESS"),
            version: version
        });
    }

    function _checkInitParamsExist(string memory json, string memory initKey) internal pure returns (bool) {
        bytes memory rawValue = json.parseRaw(string.concat(initKey, ".initialTreasury"));
        return rawValue.length > 0;
    }

    function _readParamsFromJson(string memory json, string memory initKey, string memory version)
        internal
        pure
        returns (InitializeParams memory)
    {
        InitializeParams memory params;
        params.version = version;

        // Try to read each parameter
        bytes memory rawValue = json.parseRaw(string.concat(initKey, ".initialTreasury"));
        if (rawValue.length > 0) {
            params.initialTreasury = _parseAddress(abi.decode(rawValue, (string)));
        }

        rawValue = json.parseRaw(string.concat(initKey, ".initialTransferRestrictor"));
        if (rawValue.length > 0) {
            params.initialTransferRestrictor = _parseAddress(abi.decode(rawValue, (string)));
        }

        rawValue = json.parseRaw(string.concat(initKey, ".initialOwner"));
        if (rawValue.length > 0) {
            params.initialOwner = _parseAddress(abi.decode(rawValue, (string)));
        }

        rawValue = json.parseRaw(string.concat(initKey, ".upgrader"));
        if (rawValue.length > 0) {
            params.upgrader = _parseAddress(abi.decode(rawValue, (string)));
        }

        return params;
    }

    function _parseAddress(string memory value) internal pure returns (address) {
        if (bytes(value).length == 0) return address(0);

        bytes memory addr = bytes(value);
        if (addr.length != 42) return address(0); // "0x" + 40 hex chars

        uint256 result;
        for (uint256 i = 2; i < addr.length; i++) {
            uint8 digit;
            if (addr[i] >= bytes1("0") && addr[i] <= bytes1("9")) {
                digit = uint8(addr[i]) - uint8(bytes1("0"));
            } else if (addr[i] >= bytes1("a") && addr[i] <= bytes1("f")) {
                digit = uint8(addr[i]) - uint8(bytes1("a")) + 10;
            } else if (addr[i] >= bytes1("A") && addr[i] <= bytes1("F")) {
                digit = uint8(addr[i]) - uint8(bytes1("A")) + 10;
            } else {
                return address(0);
            }
            result = result * 16 + digit;
        }

        return address(uint160(result));
    }

    // Rest of the helper functions remain the same...
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
        return abi.encodeWithSignature("reinitialize(address,string)", params.upgrader, params.version);
    }

    function _validateAddress(string memory name, address value) internal pure {
        if (value == address(0)) {
            revert InvalidAddress(name, value);
        }
    }

    function _parseVersion(string memory version) internal pure returns (uint8 major, uint8 minor) {
        bytes memory versionBytes = bytes(version);
        uint256 pos = 0;
        major = 0;
        minor = 0;

        // Parse major version
        while (pos < versionBytes.length && versionBytes[pos] != ".") {
            major = major * 10 + uint8(uint8(versionBytes[pos]) - 48);
            pos++;
        }
        if (pos >= versionBytes.length) revert InvalidAbiFormat();
        pos++;

        // Parse minor version
        while (pos < versionBytes.length && versionBytes[pos] != ".") {
            minor = minor * 10 + uint8(uint8(versionBytes[pos]) - 48);
            pos++;
        }
    }

    function _toLowerSnakeCase(string memory input) internal pure returns (string memory) {
        bytes memory inputBytes = bytes(input);
        bytes memory result = new bytes(inputBytes.length);

        for (uint256 i = 0; i < inputBytes.length; i++) {
            bytes1 char = inputBytes[i];
            result[i] = char >= 0x41 && char <= 0x5A ? bytes1(uint8(char) + 32) : char;
        }
        return string(result);
    }
}
