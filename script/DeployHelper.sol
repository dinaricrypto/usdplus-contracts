// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {JsonHandler} from "./JsonHandler.sol";
import {InitializeParams} from "./InitializeParams.sol";

contract DeployHelper is Script {
    using stdJson for string;

    error MissingRequiredParam(string name);
    error InvalidAddress(string name, address value);
    error JsonParsingError();
    error InitMethodNotFound();
    error InvalidAbiFormat();
    error VersionNotFound(string version);
    error EnvironmentNotFound(string environment);
    error UnsupportedContract(string contractName);

    function getInitializeParams(string memory contractName, string memory version, string memory environment)
        public
        returns (bytes memory)
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

        bytes32 contractHash = keccak256(bytes(contractName));
        if (contractHash == keccak256(bytes("UsdPlus"))) {
            return _handleUsdPlusParams(json, isNewFile, jsonPath, contractName, version, environment);
        } else if (contractHash == keccak256(bytes("CCIPWaypoint"))) {
            return _handleCCIPWaypointParams(json, isNewFile, jsonPath, contractName, version, environment);
        } else if (contractHash == keccak256(bytes("UsdPlusMinter"))) {
            return _handleUsdPlusMinterParams(json, isNewFile, jsonPath, contractName, version, environment);
        } else if (contractHash == keccak256(bytes("UsdPlusRedeemer"))) {
            return _handleUsdPlusRedeemerParams(json, isNewFile, jsonPath, contractName, version, environment);
        } else if (contractHash == keccak256(bytes("WrappedUsdPlus"))) {
            return _handleWrappedUsdPlusParams(json, isNewFile, jsonPath, contractName, version, environment);
        } else if (contractHash == keccak256(bytes("TransferRestrictor"))) {
            return _handleTransferRestrictorParams(json, isNewFile, jsonPath, contractName, version, environment);
        }

        revert UnsupportedContract(contractName);
    }

    function _handleUsdPlusParams(
        string memory json,
        bool isNewFile,
        string memory jsonPath,
        string memory contractName,
        string memory version,
        string memory environment
    ) internal returns (bytes memory) {
        InitializeParams.UsdPlusInitializeParams memory params = _getUsdPlusInitialParams(version);

        if (isNewFile) {
            json = JsonHandler._createUsdPlusInitialJson(contractName, version, environment, params);
            vm.writeFile(jsonPath, json);
        } else {
            string memory initKey = string.concat(".initialization.", version, ".", environment);
            bool paramsExist = _checkInitParamsExist(json, initKey);

            if (!paramsExist) {
                json = JsonHandler._updateUsdPlusInitializationParams(json, version, environment, params);
                vm.writeFile(jsonPath, json);
            } else {
                params = _readUsdPlusParamsFromJson(json, initKey, version);
            }
        }

        _validateAddress("treasury", params.initialTreasury);
        _validateAddress("transferRestrictor", params.initialTransferRestrictor);
        _validateAddress("owner", params.initialOwner);
        _validateAddress("upgrader", params.upgrader);

        // Return the encoded parameters without the function signature
        return
            abi.encode(params.initialTreasury, params.initialTransferRestrictor, params.initialOwner, params.upgrader);
    }

    function _handleUsdPlusMinterParams(
        string memory json,
        bool isNewFile,
        string memory jsonPath,
        string memory contractName,
        string memory version,
        string memory environment
    ) internal returns (bytes memory) {
        InitializeParams.UsdPlusMinterInitializeParams memory params = _getUsdPlusMinterInitialParams(version);

        if (isNewFile) {
            json = JsonHandler._createUsdPlusMinterInitialJson(contractName, version, environment, params);
            vm.writeFile(jsonPath, json);
        } else {
            string memory initKey = string.concat(".initialization.", version, ".", environment);
            bool paramsExist = _checkInitParamsExist(json, initKey);

            if (!paramsExist) {
                json = JsonHandler._updateUsdPlusMinterInitializationParams(json, version, environment, params);
                vm.writeFile(jsonPath, json);
            } else {
                params = _readUsdPlusMinterParamsFromJson(json, initKey, version);
            }
        }

        _validateAddress("usdplus", params.usdPlus);
        _validateAddress("paymentRecipient", params.initialPaymentRecipient);
        _validateAddress("owner", params.initialOwner);
        _validateAddress("upgrader", params.upgrader);

        return abi.encodeWithSignature(
            "initialize(address,address,address,address,string)",
            params.usdPlus,
            params.initialPaymentRecipient,
            params.initialOwner,
            params.upgrader,
            params.version
        );
    }

    function _handleCCIPWaypointParams(
        string memory json,
        bool isNewFile,
        string memory jsonPath,
        string memory contractName,
        string memory version,
        string memory environment
    ) internal returns (bytes memory) {
        InitializeParams.CCIPWaypointInitializeParams memory params = _getCCIPWaypointInitialParams(version);

        if (isNewFile) {
            json = JsonHandler._createCCIPWaypointInitialJson(contractName, version, environment, params);
            vm.writeFile(jsonPath, json);
        } else {
            string memory initKey = string.concat(".initialization.", version, ".", environment);
            bool paramsExist = _checkInitParamsExist(json, initKey);

            if (!paramsExist) {
                json = JsonHandler._updateCCIPWayPointIntializationParams(json, version, environment, params);
                vm.writeFile(jsonPath, json);
            } else {
                params = _readCCIPWaypointParamsFromJson(json, initKey, version);
            }
        }

        _validateAddress("usdplus", params.usdPlus);
        _validateAddress("router", params.router);
        _validateAddress("owner", params.initialOwner);
        _validateAddress("upgrader", params.upgrader);

        return abi.encodeWithSignature(
            "initialize(address,address,address,address)",
            params.usdPlus,
            params.router,
            params.initialOwner,
            params.upgrader
        );
    }

    function _handleUsdPlusRedeemerParams(
        string memory json,
        bool isNewFile,
        string memory jsonPath,
        string memory contractName,
        string memory version,
        string memory environment
    ) internal returns (bytes memory) {
        InitializeParams.UsdPlusRedeemerInitializeParams memory params = _getUsdPlusRedeemerInitialParams(version);

        if (isNewFile) {
            json = JsonHandler._createUsdPlusRedeemerInitialJson(contractName, version, environment, params);
            vm.writeFile(jsonPath, json);
        } else {
            string memory initKey = string.concat(".initialization.", version, ".", environment);
            bool paramsExist = _checkInitParamsExist(json, initKey);

            if (!paramsExist) {
                json = JsonHandler._updateUsdPlusRedeemerInitializationParams(json, version, environment, params);
                vm.writeFile(jsonPath, json);
            } else {
                params = _readUsdPlusRedeemerParamsFromJson(json, initKey, version);
            }
        }

        _validateAddress("usdplus", params.usdPlus);
        _validateAddress("owner", params.initialOwner);
        _validateAddress("upgrader", params.upgrader);

        return abi.encodeWithSignature(
            "initialize(address,address,address)", params.usdPlus, params.initialOwner, params.upgrader
        );
    }

    function _handleWrappedUsdPlusParams(
        string memory json,
        bool isNewFile,
        string memory jsonPath,
        string memory contractName,
        string memory version,
        string memory environment
    ) internal returns (bytes memory) {
        InitializeParams.WrappedUsdPlusInitializeParams memory params = _getWrappedUsdPlusInitialParams(version);

        if (isNewFile) {
            json = JsonHandler._createWrappedUsdPlusInitialJson(contractName, version, environment, params);
            vm.writeFile(jsonPath, json);
        } else {
            string memory initKey = string.concat(".initialization.", version, ".", environment);
            bool paramsExist = _checkInitParamsExist(json, initKey);

            if (!paramsExist) {
                json = JsonHandler._updateWrappedUsdPlusInitializationParams(json, version, environment, params);
                vm.writeFile(jsonPath, json);
            } else {
                params = _readWrappedUsdPlusParamsFromJson(json, initKey, version);
            }
        }

        _validateAddress("usdplus", params.usdplus);
        _validateAddress("owner", params.initialOwner);
        _validateAddress("upgrader", params.upgrader);

        return abi.encodeWithSignature(
            "initialize(address,address,address)", params.usdplus, params.initialOwner, params.upgrader
        );
    }

    function _handleTransferRestrictorParams(
        string memory json,
        bool isNewFile,
        string memory jsonPath,
        string memory contractName,
        string memory version,
        string memory environment
    ) internal returns (bytes memory) {
        InitializeParams.TransferRestrictorInitializeParams memory params = _getTransferRestrictorInitialParams(version);

        if (isNewFile) {
            json = JsonHandler._createTransferRestrictorInitialJson(contractName, version, environment, params);
            vm.writeFile(jsonPath, json);
        } else {
            string memory initKey = string.concat(".initialization.", version, ".", environment);
            bool paramsExist = _checkInitParamsExist(json, initKey);

            if (!paramsExist) {
                json = JsonHandler._updateTransferRestrictorInitializationParams(json, version, environment, params);
                vm.writeFile(jsonPath, json);
            } else {
                params = _readTransferRestrictorParamsFromJson(json, initKey, version);
            }
        }

        _validateAddress("owner", params.initialOwner);
        _validateAddress("upgrader", params.upgrader);

        return abi.encodeWithSignature("initialize(address,address)", params.initialOwner, params.upgrader);
    }

    function _getUsdPlusMinterInitialParams(string memory version)
        internal
        view
        returns (InitializeParams.UsdPlusMinterInitializeParams memory)
    {
        return InitializeParams.UsdPlusMinterInitializeParams({
            usdPlus: vm.envAddress("USDPLUS_ADDRESS"),
            initialPaymentRecipient: vm.envAddress("PAYMENT_RECIPIENT_ADDRESS"),
            initialOwner: vm.envAddress("OWNER_ADDRESS"),
            upgrader: vm.envAddress("UPGRADER_ADDRESS"),
            version: version
        });
    }

    function _getUsdPlusInitialParams(string memory version)
        internal
        view
        returns (InitializeParams.UsdPlusInitializeParams memory)
    {
        return InitializeParams.UsdPlusInitializeParams({
            initialTreasury: vm.envAddress("TREASURY_ADDRESS"),
            initialTransferRestrictor: vm.envAddress("TRANSFER_RESTRICTOR"),
            initialOwner: vm.envAddress("OWNER_ADDRESS"),
            upgrader: vm.envAddress("UPGRADER_ADDRESS"),
            version: version
        });
    }

    function _getCCIPWaypointInitialParams(string memory version)
        internal
        view
        returns (InitializeParams.CCIPWaypointInitializeParams memory)
    {
        return InitializeParams.CCIPWaypointInitializeParams({
            usdPlus: vm.envAddress("USDPLUS_ADDRESS"),
            router: vm.envAddress("ROUTER_ADDRESS"),
            initialOwner: vm.envAddress("OWNER_ADDRESS"),
            upgrader: vm.envAddress("UPGRADER_ADDRESS"),
            version: version
        });
    }

    function _getUsdPlusRedeemerInitialParams(string memory version)
        internal
        view
        returns (InitializeParams.UsdPlusRedeemerInitializeParams memory)
    {
        return InitializeParams.UsdPlusRedeemerInitializeParams({
            usdPlus: vm.envAddress("USDPLUS_ADDRESS"),
            initialOwner: vm.envAddress("OWNER_ADDRESS"),
            upgrader: vm.envAddress("UPGRADER_ADDRESS"),
            version: version
        });
    }

    function _getWrappedUsdPlusInitialParams(string memory version)
        internal
        view
        returns (InitializeParams.WrappedUsdPlusInitializeParams memory)
    {
        return InitializeParams.WrappedUsdPlusInitializeParams({
            usdplus: vm.envAddress("USDPLUS_ADDRESS"),
            initialOwner: vm.envAddress("OWNER_ADDRESS"),
            upgrader: vm.envAddress("UPGRADER_ADDRESS"),
            version: version
        });
    }

    function _getTransferRestrictorInitialParams(string memory version)
        internal
        view
        returns (InitializeParams.TransferRestrictorInitializeParams memory)
    {
        return InitializeParams.TransferRestrictorInitializeParams({
            initialOwner: vm.envAddress("OWNER_ADDRESS"),
            upgrader: vm.envAddress("UPGRADER_ADDRESS"),
            version: version
        });
    }

    function _checkInitParamsExist(string memory json, string memory initKey) internal pure returns (bool) {
        bytes memory rawValue = json.parseRaw(string.concat(initKey, ".initialTreasury"));
        return rawValue.length > 0;
    }

    function _readUsdPlusParamsFromJson(string memory json, string memory initKey, string memory version)
        internal
        pure
        returns (InitializeParams.UsdPlusInitializeParams memory)
    {
        InitializeParams.UsdPlusInitializeParams memory params;
        params.version = version;

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

    function _readUsdPlusMinterParamsFromJson(string memory json, string memory initKey, string memory version)
        internal
        pure
        returns (InitializeParams.UsdPlusMinterInitializeParams memory)
    {
        InitializeParams.UsdPlusMinterInitializeParams memory params;
        params.version = version;

        bytes memory rawValue = json.parseRaw(string.concat(initKey, ".usdPlus"));
        if (rawValue.length > 0) {
            params.usdPlus = _parseAddress(abi.decode(rawValue, (string)));
        }

        rawValue = json.parseRaw(string.concat(initKey, ".initialPaymentRecipient"));
        if (rawValue.length > 0) {
            params.initialPaymentRecipient = _parseAddress(abi.decode(rawValue, (string)));
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

    function _readUsdPlusRedeemerParamsFromJson(string memory json, string memory initKey, string memory version)
        internal
        pure
        returns (InitializeParams.UsdPlusRedeemerInitializeParams memory)
    {
        InitializeParams.UsdPlusRedeemerInitializeParams memory params;
        params.version = version;

        bytes memory rawValue = json.parseRaw(string.concat(initKey, ".usdPlus"));
        if (rawValue.length > 0) {
            params.usdPlus = _parseAddress(abi.decode(rawValue, (string)));
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

    function _readWrappedUsdPlusParamsFromJson(string memory json, string memory initKey, string memory version)
        internal
        pure
        returns (InitializeParams.WrappedUsdPlusInitializeParams memory)
    {
        InitializeParams.WrappedUsdPlusInitializeParams memory params;
        params.version = version;

        bytes memory rawValue = json.parseRaw(string.concat(initKey, ".usdplus"));
        if (rawValue.length > 0) {
            params.usdplus = _parseAddress(abi.decode(rawValue, (string)));
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

    function _readCCIPWaypointParamsFromJson(string memory json, string memory initKey, string memory version)
        internal
        pure
        returns (InitializeParams.CCIPWaypointInitializeParams memory)
    {
        InitializeParams.CCIPWaypointInitializeParams memory params;
        params.version = version;

        bytes memory rawValue = json.parseRaw(string.concat(initKey, ".usdPlus"));
        if (rawValue.length > 0) {
            params.usdPlus = _parseAddress(abi.decode(rawValue, (string)));
        }

        rawValue = json.parseRaw(string.concat(initKey, ".router"));
        if (rawValue.length > 0) {
            params.router = _parseAddress(abi.decode(rawValue, (string)));
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

    function _readTransferRestrictorParamsFromJson(string memory json, string memory initKey, string memory version)
        internal
        pure
        returns (InitializeParams.TransferRestrictorInitializeParams memory)
    {
        InitializeParams.TransferRestrictorInitializeParams memory params;
        params.version = version;

        bytes memory rawValue = json.parseRaw(string.concat(initKey, ".initialOwner"));
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

    function getInitializeCalldata(string memory contractName, bytes memory params)
        public
        pure
        returns (bytes memory)
    {
        bytes32 contractHash = keccak256(bytes(contractName));

        if (contractHash == keccak256(bytes("UsdPlus"))) {
            return abi.encodeWithSignature("initialize(address,address,address,address)", params);
        } else if (contractHash == keccak256(bytes("CCIPWaypoint"))) {
            return abi.encodeWithSignature("initialize(address,address,address,address)", params);
        } else if (contractHash == keccak256(bytes("UsdPlusMinter"))) {
            return abi.encodeWithSignature("initialize(address,address,address,address)", params);
        } else if (contractHash == keccak256(bytes("UsdPlusRedeemer"))) {
            return abi.encodeWithSignature("initialize(address,address,address)", params);
        } else if (contractHash == keccak256(bytes("WrappedUsdPlus"))) {
            return abi.encodeWithSignature("initialize(address,address,address)", params);
        } else if (contractHash == keccak256(bytes("TransferRestrictor"))) {
            return abi.encodeWithSignature("initialize(address,address)", params);
        }
        revert UnsupportedContract(contractName);
    }

    function getReinitializeCalldata(string memory contractName, bytes memory params)
        public
        pure
        returns (bytes memory)
    {
        bytes32 contractHash = keccak256(bytes(contractName));

        if (contractHash == keccak256(bytes("CCIPWaypoint"))) {
            InitializeParams.CCIPWaypointInitializeParams memory ccipParams =
                abi.decode(params, (InitializeParams.CCIPWaypointInitializeParams));
            return
                abi.encodeWithSignature("reinitialize(address,address)", ccipParams.initialOwner, ccipParams.upgrader);
        }

        // All other contracts just need upgrader
        InitializeParams.BaseInitializeParams memory baseParams =
            abi.decode(params, (InitializeParams.BaseInitializeParams));
        return abi.encodeWithSignature("reinitialize(address)", baseParams.upgrader);
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
