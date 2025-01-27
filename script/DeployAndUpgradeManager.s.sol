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
        mapping(string => mapping(uint256 => address)) deployments; //
    }

    function run() external {
        // Get environment variables
        string memory contractName = vm.envString("CONTRACT");
        string memory version = vm.envString("VERSION");
        string memory environment = vm.envString("ENVIRONMENT");
        uint256 chainId = block.chainid;

        // Validate inputs
        require(bytes(contractName).length > 0, "CONTRACT_NAME not set");
        require(bytes(version).length > 0, "VERSION not set");
        require(bytes(environment).length > 0, "ENVIRONMENT not set");
        require(_isValidVersion(version), "Invalid VERSION format");

        // Setup paths
        string memory configPath = string.concat("release_config/", vm.toString(chainId), ".json");
        string memory releasePath = string.concat("releases/", version);
        string memory jsonPath = string.concat(releasePath, "/", contractName, ".json");

        // Read config first to ensure it exists
        string memory configJson = vm.readFile(configPath);
        bytes memory initParams = configJson.parseRaw(string.concat(".", contractName));

        // Check for existing deployment from previous version
        address existingAddr = _getExistingDeployment(contractName, version, environment, chainId);
        address proxyAddress;

        // Create or read current version's release JSON file
        string memory releaseJson;
        if (!vm.exists(releasePath)) {
            vm.createDir(releasePath, true);
        }

        if (!vm.exists(jsonPath)) {
            releaseJson = _getInitialJson(contractName, version);
            vm.writeFile(jsonPath, releaseJson);
        } else {
            try vm.readFile(jsonPath) returns (string memory content) {
                releaseJson = content;
            } catch {
                releaseJson = _getInitialJson(contractName, version);
                vm.writeFile(jsonPath, releaseJson);
            }
        }

        console2.log("Release JSON:", releaseJson);

        // Deploy or upgrade based on existing deployment
        vm.startBroadcast();
        if (existingAddr != address(0)) {
            console2.log("Upgrading existing deployment at:", existingAddr);
            bytes memory upgradeData = _getInitData(contractName, initParams, true);
            proxyAddress = _upgradeContract(contractName, existingAddr, upgradeData);
        } else {
            console2.log("Deploying new contract");
            bytes memory initData = _getInitData(contractName, initParams, false);
            proxyAddress = _deployNewContract(contractName, initData);
        }
        vm.stopBroadcast();

        // Update deployments in current version's JSON
        _updateDeployments(releaseJson, environment, chainId, proxyAddress);

        console2.log("Deployment completed. Proxy address:", proxyAddress);
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
        // Get all release directories
        VmSafe.DirEntry[] memory dirEntries = vm.readDir("releases");

        // Filter and collect valid versions that have our contract
        string[] memory versions = new string[](dirEntries.length);
        uint256 validCount = 0;
        for (uint256 i = 0; i < dirEntries.length; i++) {
            string memory dirName = _getDirectoryName(dirEntries[i].path);
            if (_isValidVersion(dirName)) {
                versions[validCount] = dirName;
                validCount++;
            }
        }

        // Return if no valid versions found
        if (validCount == 0) return address(0);

        // Resize array to valid count
        string[] memory filteredVersions = new string[](validCount);
        for (uint256 i = 0; i < validCount; i++) {
            filteredVersions[i] = versions[i];
        }

        // Sort versions in descending order
        filteredVersions = _sortVersionsDescending(filteredVersions);

        // Look through versions from newest to oldest to find latest deployment
        address deployedAddress = address(0);
        string memory deployedVersion;

        for (uint256 i = 0; i < filteredVersions.length; i++) {
            string memory version = filteredVersions[i];
            string memory contractJsonPath = string.concat("releases/", version, "/", contractName, ".json");

            // Skip if contract doesn't exist in this version
            if (!vm.exists(contractJsonPath)) continue;

            // Read and parse contract JSON
            string memory contractJson = vm.readFile(contractJsonPath);
            if (bytes(contractJson).length == 0) continue;

            // Try to get deployment address for environment and chain
            string memory jsonPath = string.concat(".deployments.", environment, ".", vm.toString(chainId));

            try vm.parseJsonAddress(contractJson, jsonPath) returns (address addr) {
                if (addr != address(0)) {
                    deployedAddress = addr;
                    deployedVersion = version;
                    break; // Found the latest deployed version
                }
            } catch {
                continue; // No deployment in this version, try older version
            }
        }

        if (deployedAddress != address(0)) {
            console.log("Found existing deployment of", contractName, "version", deployedVersion);
            return deployedAddress;
        }

        console2.log("No existing version found for", contractName, "in environment", environment);

        return address(0);
    }

    // Helper function to get directory name from path
    function _getDirectoryName(string memory path) internal pure returns (string memory) {
        bytes memory pathBytes = bytes(path);
        uint256 lastSlash = pathBytes.length;

        for (uint256 i = pathBytes.length - 1; i > 0; i--) {
            if (pathBytes[i] == 0x2f) {
                // '/'
                lastSlash = i + 1;
                break;
            }
        }

        bytes memory dirName = new bytes(pathBytes.length - lastSlash);
        for (uint256 i = 0; i < dirName.length; i++) {
            dirName[i] = pathBytes[lastSlash + i];
        }

        return string(dirName);
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
    {
        string memory contractName = vm.envString("CONTRACT");
        string memory version = vm.envString("VERSION");

        if (bytes(json).length == 0) {
            json = _getInitialJson(contractName, version);
        }

        // Parse base chains JSON to get the template
        string memory baseChains = _initChainIds();

        // Update the specific chain in the template
        string memory updatedChains = _updateChainAddress(baseChains, chainId, deployedAddress);

        bytes32 envHash = keccak256(bytes(environment));
        bytes32 stagingHash = keccak256(bytes("staging"));
        bytes32 productionHash = keccak256(bytes("production"));

        // Construct the final JSON with the current environment having the updated chains
        string memory updatedJson = string(
            abi.encodePacked(
                "{",
                '"name":"',
                contractName,
                '",',
                '"version":"',
                version,
                '",',
                '"deployments":{',
                '"production":',
                envHash == productionHash ? updatedChains : _initChainIds(),
                ",",
                '"staging":',
                envHash == stagingHash ? updatedChains : _initChainIds(),
                "}}"
            )
        );

        string memory jsonPath = string.concat("releases/", version, "/", contractName, ".json");
        vm.writeFile(jsonPath, updatedJson);
    }

    function _updateChainAddress(string memory baseChains, uint256 chainId, address deployedAddress)
        internal
        view
        returns (string memory)
    {
        // Find the position of the chainId in the template
        string memory chainIdStr = vm.toString(chainId);
        string memory searchStr = string.concat('"', chainIdStr, '":"');

        // If we can't find the chain ID, return base unchanged
        bytes memory baseBytes = bytes(baseChains);
        bytes memory searchBytes = bytes(searchStr);
        uint256 pos = _findSubstring(baseBytes, searchBytes);
        if (pos == type(uint256).max) return baseChains;

        // Find the end of the current address (next quote)
        uint256 endPos = pos + searchBytes.length;
        while (endPos < baseBytes.length && baseBytes[endPos] != '"') {
            endPos++;
        }

        // Construct the updated JSON with the new address
        return string(
            abi.encodePacked(
                _sliceBytes(baseBytes, 0, pos + searchBytes.length),
                vm.toString(deployedAddress),
                _sliceBytes(baseBytes, endPos, baseBytes.length)
            )
        );
    }

    function _findSubstring(bytes memory str, bytes memory substr) internal pure returns (uint256) {
        if (substr.length == 0) return 0;
        if (str.length < substr.length) return type(uint256).max;

        for (uint256 i = 0; i <= str.length - substr.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < substr.length; j++) {
                if (str[i + j] != substr[j]) {
                    found = false;
                    break;
                }
            }
            if (found) return i;
        }
        return type(uint256).max;
    }

    function _sliceBytes(bytes memory data, uint256 start, uint256 end) internal pure returns (bytes memory) {
        bytes memory result = new bytes(end - start);
        for (uint256 i = start; i < end; i++) {
            result[i - start] = data[i];
        }
        return result;
    }

    function _getInitialJson(string memory contractName, string memory version) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                '{"name":"', contractName, '","version":"', version, '","deployments":', _initDeployments(), "}"
            )
        );
    }

    function _initDeployments() internal pure returns (string memory) {
        return string(abi.encodePacked('{"production":', _initChainIds(), ',"staging":', _initChainIds(), "}"));
    }

    function _initChainIds() internal pure returns (string memory) {
        return
        '{"1":"","11155111":"","42161":"","421614":"","8453":"","84532":"","81457":"","168587773":"","7887":"","161221135":"","98865":"","98864":""}';
    }
}
