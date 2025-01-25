// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ControlledUpgradeable} from "../src/deployment/ControlledUpgradeable.sol";
import {console} from "forge-std/console.sol";
import {console2} from "forge-std/console2.sol";

import {VmSafe} from "forge-std/Vm.sol";

contract DeployManager is Script {
    using stdJson for string;

    error InvalidJsonFormat();

    string constant DEPLOYMENTS_KEY = "deployments";

    struct DeploymentConfig {
        string version;
        mapping(string => mapping(uint256 => address)) deployments; // environment -> chainId -> address
    }

    function run() external {
        string memory contractName = vm.envString("CONTRACT");
        string memory version = vm.envString("VERSION");
        string memory environment = vm.envString("ENVIRONMENT");
        uint256 chainId = block.chainid;

        require(bytes(contractName).length > 0, "CONTRACT_NAME not set");
        require(bytes(version).length > 0, "VERSION not set");
        require(bytes(environment).length > 0, "ENVIRONMENT not set");
        require(_isValidVersion(version), "Invalid VERSION format");

        // Load chain-specific config
        string memory configPath = string.concat("release_config/", vm.toString(chainId), ".json");
        string memory configJson = vm.readFile(configPath);
        bytes memory initParams = configJson.parseRaw(string.concat(".", contractName));

        // Check existing deployment
        address existingAddr = _getExistingDeployment(contractName, version, environment, chainId);
        address proxyAddress;

        vm.startBroadcast();
        if (existingAddr != address(0)) {
            bytes memory upgradeData = _getInitData(contractName, initParams, true);
            proxyAddress = _upgradeContract(contractName, existingAddr, upgradeData);
        } else {
            bytes memory initData = _getInitData(contractName, initParams, false);
            proxyAddress = _deployNewContract(contractName, initData);
        }
        vm.stopBroadcast();

        _recordDeployment(contractName, version, environment, chainId, proxyAddress);
    }

    function _getInitData(string memory contractName, bytes memory params, bool isUpgrade)
        internal
        pure
        returns (bytes memory)
    {
        bytes32 nameHash = keccak256(bytes(contractName));

        if (nameHash == keccak256(bytes("UsdPlus"))) {
            return _handleUsdPlus(params, isUpgrade);
        }
        if (nameHash == keccak256(bytes("TransferRestrictor"))) {
            return _handleTransferRestrictor(params, isUpgrade);
        }
        if (nameHash == keccak256(bytes("CCIPWaypoint"))) {
            return _handleCCIPWaypoint(params, isUpgrade);
        }
        if (nameHash == keccak256(bytes("UsdPlusMinter"))) {
            return _handleUsdPlusMinter(params, isUpgrade);
        }
        if (nameHash == keccak256(bytes("UsdPlusRedeemer"))) {
            return _handleUsdPlusRedeemer(params, isUpgrade);
        }
        revert(string.concat("Unsupported contract: ", contractName));
    }

    function _handleUsdPlus(bytes memory params, bool isUpgrade) private pure returns (bytes memory) {
        if (isUpgrade) {
            address upgrader = abi.decode(params, (address));
            return abi.encodeWithSignature("reinitialize(address)", upgrader);
        }

        (address treasury, address restrictor, address owner, address upgrader) =
            abi.decode(params, (address, address, address, address));
        return abi.encodeWithSignature(
            "initialize(address,address,address,address)", treasury, restrictor, owner, upgrader
        );
    }

    function _handleTransferRestrictor(bytes memory params, bool isUpgrade) private pure returns (bytes memory) {
        if (isUpgrade) return bytes(""); // No reinitialization needed

        (address owner, address upgrader) = abi.decode(params, (address, address));
        return abi.encodeWithSignature("initialize(address,address)", owner, upgrader);
    }

    function _handleCCIPWaypoint(bytes memory params, bool isUpgrade) private pure returns (bytes memory) {
        if (isUpgrade) {
            address upgrader = abi.decode(params, (address));
            return abi.encodeWithSignature("reinitialize(address)", upgrader);
        }

        (address usdPlus, address router, address owner, address upgrader) =
            abi.decode(params, (address, address, address, address));
        return abi.encodeWithSignature("initialize(address,address,address,address)", usdPlus, router, owner, upgrader);
    }

    function _handleUsdPlusMinter(bytes memory params, bool isUpgrade) private pure returns (bytes memory) {
        if (isUpgrade) {
            address upgrader = abi.decode(params, (address));
            return abi.encodeWithSignature("reinitialize(address)", upgrader);
        }

        (address usdPlus, address paymentRecipient, address owner, address upgrader) =
            abi.decode(params, (address, address, address, address));
        return abi.encodeWithSignature(
            "initialize(address,address,address,address)", usdPlus, paymentRecipient, owner, upgrader
        );
    }

    function _handleUsdPlusRedeemer(bytes memory params, bool isUpgrade) private pure returns (bytes memory) {
        if (isUpgrade) {
            address upgrader = abi.decode(params, (address));
            return abi.encodeWithSignature("reinitialize(address)", upgrader);
        }

        (address usdPlus, address owner, address upgrader) = abi.decode(params, (address, address, address));
        return abi.encodeWithSignature("initialize(address,address,address)", usdPlus, owner, upgrader);
    }

    function _deployNewContract(string memory contractName, bytes memory initData) internal returns (address) {
        address implementation = _deployImplementation(contractName);
        ERC1967Proxy proxy = new ERC1967Proxy(implementation, initData);
        console.log("Deployed %s at %s", contractName, address(proxy));
        return address(proxy);
    }

    function _upgradeContract(string memory contractName, address proxyAddress, bytes memory upgradeData)
        internal
        returns (address)
    {
        address implementation = _deployImplementation(contractName);
        if (upgradeData.length > 0) {
            ControlledUpgradeable(payable(proxyAddress)).upgradeToAndCall(implementation, upgradeData);
        } else {
            revert("Upgrade data not provided");
        }
        console.log("Upgraded %s at %s", contractName, proxyAddress);
        return proxyAddress;
    }

    // Helper functions remain similar to previous implementation
    function _deployImplementation(string memory contractName) internal returns (address) {
        bytes memory creationCode = vm.getCode(string.concat(contractName, ".sol:", contractName));
        require(creationCode.length > 0, string.concat("Contract code not found: ", contractName));

        address implementation;
        assembly {
            implementation := create(0, add(creationCode, 0x20), mload(creationCode))
        }
        require(implementation != address(0), "Implementation deployment failed");
        return implementation;
    }

    function _getExistingDeployment(
        string memory contractName,
        string memory currentVersion,
        string memory environment,
        uint256 chainId
    ) internal returns (address) {
        // Fixed directory reading with DirEntry handling
        VmSafe.DirEntry[] memory dirEntries = vm.readDir("releases");
        string[] memory allEntries = new string[](dirEntries.length);
        for (uint256 i = 0; i < dirEntries.length; i++) {
            allEntries[i] = dirEntries[i].path;
        }

        // Filter valid semantic versions
        string[] memory versions = new string[](allEntries.length);
        uint256 validCount = 0;
        for (uint256 i = 0; i < allEntries.length; i++) {
            if (_isValidVersion(allEntries[i])) {
                versions[validCount++] = allEntries[i];
            }
        }

        // Get all released versions from filesystem
        if (versions.length == 0) return address(0);
        versions = _sortVersionsDescending(versions);

        // Resize array
        string[] memory filteredVersions = new string[](validCount);
        for (uint256 i = 0; i < validCount; i++) {
            filteredVersions[i] = versions[i];
        }

        if (filteredVersions.length == 0) return address(0);
        // Sort versions in descending order
        versions = _sortVersionsDescending(versions);

        // Find the latest version older than current
        string memory prevVersion;
        for (uint256 i = 0; i < versions.length; i++) {
            if (_compareVersions(versions[i], currentVersion) < 0) {
                prevVersion = versions[i];
                break;
            }
        }

        if (bytes(prevVersion).length == 0) return address(0);

        // Load deployment from chain-specific file
        string memory deploymentPath = string.concat("releases/", prevVersion, "/", vm.toString(chainId), ".json");

        if (!vm.exists(deploymentPath)) return address(0);

        string memory deploymentJson = vm.readFile(deploymentPath);
        if (bytes(deploymentJson).length == 0) return address(0);

        return deploymentJson.readAddress(string.concat(".", contractName, ".", environment));
    }

    function _isValidVersion(string memory version) internal pure returns (bool) {
        bytes memory v = bytes(version);
        if (v.length < 5 || v[0] != "v") return false;
        uint256 dotCount = 0;
        for (uint256 i = 1; i < v.length; i++) {
            if (v[i] == ".") dotCount++;
        }
        return dotCount == 2;
    }

    function _sortVersionsDescending(string[] memory versions) internal pure returns (string[] memory) {
        string[] memory sorted = versions;
        for (uint256 i = 1; i < sorted.length; i++) {
            string memory key = sorted[i];
            uint256 j = i;
            while (j > 0 && _compareVersions(sorted[j - 1], key) < 0) {
                sorted[j] = sorted[j - 1];
                j--;
            }
            sorted[j] = key;
        }
        return sorted;
    }

    function _compareVersions(string memory a, string memory b) internal pure returns (int256) {
        (uint256 aMajor, uint256 aMinor, uint256 aPatch) = _parseVersion(a);
        (uint256 bMajor, uint256 bMinor, uint256 bPatch) = _parseVersion(b);

        // Explicit int256 casting
        if (aMajor != bMajor) {
            return aMajor > bMajor ? int256(1) : int256(-1);
        }
        if (aMinor != bMinor) {
            return aMinor > bMinor ? int256(1) : int256(-1);
        }
        if (aPatch != bPatch) {
            return aPatch > bPatch ? int256(1) : int256(-1);
        }
        return 0;
    }

    function _parseVersion(string memory version) internal pure returns (uint256 major, uint256 minor, uint256 patch) {
        bytes memory v = bytes(version);
        uint256[3] memory parts;
        uint256 partIndex = 0;
        uint256 start = 1; // Skip 'v' prefix

        for (uint256 i = start; i < v.length; i++) {
            if (v[i] == ".") {
                parts[partIndex] = _parseNumber(v, start, i);
                start = i + 1;
                partIndex++;
                if (partIndex > 2) break;
            }
        }

        // Parse last part
        if (partIndex < 3) {
            parts[partIndex] = _parseNumber(v, start, v.length);
        }

        return (parts[0], parts[1], parts[2]);
    }

    function _parseNumber(bytes memory version, uint256 start, uint256 end) internal pure returns (uint256) {
        uint256 result = 0;
        for (uint256 i = start; i < end; i++) {
            if (version[i] >= "0" && version[i] <= "9") {
                result = result * 10 + (uint256(uint8(version[i])) - 48);
            }
        }
        return result;
    }

    function _updateDeployments(string memory json, string memory environment, uint256 chainId, address deployedAddress)
        internal
        returns (string memory)
    {
        string memory contractName = vm.envString("CONTRACT");
        string memory version = vm.envString("VERSION");

        if (bytes(json).length == 0) {
            json = _getInitialJson(contractName, version);
        }

        bytes32 envHash = keccak256(bytes(environment));
        bytes32 stagingHash = keccak256(bytes("staging"));
        bytes32 productionHash = keccak256(bytes("production"));

        string memory envData = string(
            abi.encodePacked(
                '{"1":"","11155111":"',
                envHash == stagingHash && chainId == 11155111 ? vm.toString(deployedAddress) : "",
                '","42161":"","421614":"","8453":"","84532":"","81457":"","168587773":"","7887":"","161221135":""}'
            )
        );

        string memory updatedJson = string(
            abi.encodePacked(
                '{"name":"',
                contractName,
                '","version":"',
                version,
                '","deployments":{"production":',
                envHash == productionHash ? envData : _initChainIds(),
                ',"staging":',
                envHash == stagingHash ? envData : _initChainIds(),
                "}}"
            )
        );

        return updatedJson;
    }

    function _recordDeployment(
        string memory contractName,
        string memory version,
        string memory environment,
        uint256 chainId,
        address deployedAddress
    ) internal {
        string memory versionDir = string.concat("releases/", version, "/");
        vm.createDir(versionDir, true);
        string memory deploymentPath = string.concat(versionDir, contractName, ".json");

        // Initialize or load existing JSON
        string memory json =
            vm.exists(deploymentPath) ? vm.readFile(deploymentPath) : _getInitialJson(contractName, version);

        // Update the specific deployment while preserving structure
        json = _updateDeployments(json, environment, chainId, deployedAddress);

        // Write back to file
        vm.writeJson(json, deploymentPath);
    }

    function _fixJsonStructure(string memory json) internal pure returns (string memory) {
        bytes memory jsonBytes = bytes(json);
        uint256 lastBrace = _findLastBrace(jsonBytes);
        if (lastBrace != jsonBytes.length - 1) {
            // Remove trailing commas and add missing braces
            return string(abi.encodePacked(_sliceBytes(jsonBytes, 0, lastBrace + 1), "}"));
        }
        return json;
    }

    function _getInitialJson(string memory contractName, string memory version) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                '{"name":"', contractName, '","version":"', version, '","deployments":', _initDeployments(), "}"
            )
        );
    }

    function _sliceBytes(bytes memory data, uint256 start, uint256 end) internal pure returns (bytes memory) {
        require(end >= start, "Invalid slice");
        require(data.length >= end, "Slice out of bounds");

        bytes memory result = new bytes(end - start);
        for (uint256 i = 0; i < end - start; i++) {
            result[i] = data[start + i];
        }
        return result;
    }

    function _findLastBrace(bytes memory data) internal pure returns (uint256) {
        for (uint256 i = data.length - 1; i > 0; i--) {
            if (data[i] == bytes1("}")) {
                return i;
            }
        }
        revert InvalidJsonFormat();
    }

    function _initDeployments() internal pure returns (string memory) {
        return string(abi.encodePacked('{"production":', _initChainIds(), ',"staging":', _initChainIds(), "}"));
    }

    function _initChainIds() internal pure returns (string memory) {
        return
        '{"1":"","11155111":"","42161":"","421614":"","8453":"","84532":"","81457":"","168587773":"","7887":"","161221135":"","98865":"","98864":""}';
    }
}
