// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ControlledUpgradeable} from "../src/deployment/ControlledUpgradeable.sol";
import {console} from "forge-std/console.sol";
import {console2} from "forge-std/console2.sol";

import {VmSafe} from "forge-std/Vm.sol";
import {VersionUtils} from "./VersionUtils.sol";

contract DeployManager is Script {
    using stdJson for string;
    using VersionUtils for string;

    struct DeploymentParams {
        string contractName;
        string version;
        string environment;
        uint256 chainId;
    }

    function run() external {
        DeploymentParams memory params = _getAndValidateParams();
        // setup path
        (string memory configPath, string memory releasePath, string memory jsonPath) = _setupPaths(params);
        // Read config first to ensure it exists
        string memory configJson = vm.readFile(configPath);
        bytes memory initParams = configJson.parseRaw(string.concat(".", params.contractName));

        // Check for existing deployment from previous version
        address existingAddr =
            _getExistingDeployment(params.contractName, params.version, params.environment, params.chainId);
        address proxyAddress;

        // Create or read current version's release JSON file
        string memory releaseJson = _getReleaseJson(jsonPath, releasePath, params);

        console2.log("Release JSON:", releaseJson);

        // Deploy or upgrade based on existing deployment
        vm.startBroadcast();
        if (existingAddr != address(0)) {
            console2.log("Upgrading existing deployment at:", existingAddr);
            bytes memory upgradeData = _getInitData(params.contractName, initParams, true);
            proxyAddress = _upgradeContract(params.contractName, existingAddr, upgradeData);
        } else {
            console2.log("Deploying new contract");
            bytes memory initData = _getInitData(params.contractName, initParams, false);
            proxyAddress = _deployNewContract(params.contractName, initData);
        }
        vm.stopBroadcast();

        // Update deployments in current version's JSON
        _updateDeployments(params.environment, params.chainId, proxyAddress);

        console2.log("Deployment completed. Proxy address:", proxyAddress);
    }

    function _setupPaths(DeploymentParams memory params)
        internal
        pure
        returns (string memory configPath, string memory releasePath, string memory jsonPath)
    {
        configPath = string.concat("release_config/", params.environment, "/", vm.toString(params.chainId), ".json");
        releasePath = string.concat("releases/", params.version);
        jsonPath = string.concat(releasePath, "/", params.contractName, ".json");
    }

    function _getReleaseJson(string memory jsonPath, string memory releasePath, DeploymentParams memory params)
        internal
        returns (string memory releaseJson)
    {
        if (!vm.exists(releasePath)) {
            vm.createDir(releasePath, true);
        }

        if (!vm.exists(jsonPath)) {
            releaseJson = _getInitialJson(params.contractName, params.version);
            vm.writeFile(jsonPath, releaseJson);
        } else {
            try vm.readFile(jsonPath) returns (string memory content) {
                releaseJson = content;
            } catch {
                releaseJson = _getInitialJson(params.contractName, params.version);
                vm.writeFile(jsonPath, releaseJson);
            }
        }
        return releaseJson;
    }

    function _getAndValidateParams() internal view returns (DeploymentParams memory) {
        string memory contractName = vm.envString("CONTRACT");
        string memory version = vm.envString("VERSION");
        string memory environment = vm.envString("ENVIRONMENT");
        uint256 chainId = block.chainid;

        require(bytes(contractName).length > 0, "CONTRACT_NAME not set");
        require(bytes(version).length > 0, "VERSION not set");
        require(bytes(environment).length > 0, "ENVIRONMENT not set");
        require(VersionUtils.isValidVersion(version), "Invalid VERSION format");

        return DeploymentParams(contractName, version, environment, chainId);
    }

    function _getInitData(string memory contractName, bytes memory params, bool isUpgrade)
        internal
        pure
        returns (bytes memory)
    {
        bytes32 nameHash = keccak256(bytes(contractName));

        if (nameHash == keccak256(bytes("UsdPlus"))) {
            return _getInitDataForUsdPlus(params, isUpgrade);
        }
        if (nameHash == keccak256(bytes("TransferRestrictor"))) {
            return _getInitDataForTransferRestrictor(params, isUpgrade);
        }
        if (nameHash == keccak256(bytes("CCIPWaypoint"))) {
            return _getInitDataForCCIPWaypoint(params, isUpgrade);
        }
        if (nameHash == keccak256(bytes("UsdPlusMinter"))) {
            return _getInitDataForUsdPlusMinter(params, isUpgrade);
        }
        if (nameHash == keccak256(bytes("UsdPlusRedeemer"))) {
            return _getInitDataForUsdPlusRedeemer(params, isUpgrade);
        }
        revert(string.concat("Unsupported contract: ", contractName));
    }

    function _getInitDataForUsdPlus(bytes memory params, bool isUpgrade) private pure returns (bytes memory) {
        if (isUpgrade) {
            address upgrader = abi.decode(params, (address));
            return abi.encodeWithSignature("reinitialize(address)", upgrader);
        }

        (address _treasury, address _restrictor, address _owner, address _upgrader) =
            abi.decode(params, (address, address, address, address));
        return abi.encodeWithSignature(
            "initialize(address,address,address,address)", _treasury, _restrictor, _owner, _upgrader
        );
    }

    function _getInitDataForTransferRestrictor(bytes memory params, bool isUpgrade)
        private
        pure
        returns (bytes memory)
    {
        if (isUpgrade) return bytes(""); // No reinitialization needed

        (address owner, address upgrader) = abi.decode(params, (address, address));
        return abi.encodeWithSignature("initialize(address,address)", owner, upgrader);
    }

    function _getInitDataForCCIPWaypoint(bytes memory params, bool isUpgrade) private pure returns (bytes memory) {
        if (isUpgrade) {
            address upgrader = abi.decode(params, (address));
            return abi.encodeWithSignature("reinitialize(address)", upgrader);
        }

        (address _usdPlus, address _router, address _owner, address _upgrader) =
            abi.decode(params, (address, address, address, address));
        return
            abi.encodeWithSignature("initialize(address,address,address,address)", _usdPlus, _router, _owner, _upgrader);
    }

    function _getInitDataForUsdPlusMinter(bytes memory params, bool isUpgrade) private pure returns (bytes memory) {
        if (isUpgrade) {
            address upgrader = abi.decode(params, (address));
            return abi.encodeWithSignature("reinitialize(address)", upgrader);
        }

        (address _usdPlus, address _paymentRecipient, address _owner, address _upgrader) =
            abi.decode(params, (address, address, address, address));
        return abi.encodeWithSignature(
            "initialize(address,address,address,address)", _usdPlus, _paymentRecipient, _owner, _upgrader
        );
    }

    function _getInitDataForUsdPlusRedeemer(bytes memory params, bool isUpgrade) private pure returns (bytes memory) {
        if (isUpgrade) {
            address upgrader = abi.decode(params, (address));
            return abi.encodeWithSignature("reinitialize(address)", upgrader);
        }

        (address _usdPlus, address _owner, address _upgrader) = abi.decode(params, (address, address, address));
        return abi.encodeWithSignature("initialize(address,address,address)", _usdPlus, _owner, _upgrader);
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

        // Filter and collect valid versions
        string[] memory versions = new string[](dirEntries.length);
        uint256 validCount = 0;
        for (uint256 i = 0; i < dirEntries.length; i++) {
            string memory dirName = VersionUtils.getDirectoryName(dirEntries[i].path);
            if (VersionUtils.isValidVersion(dirName)) {
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
        filteredVersions = VersionUtils.sortVersionsDescending(filteredVersions);

        // Look for deployments
        address deployedAddress = address(0);
        string memory deployedVersion;

        for (uint256 i = 0; i < filteredVersions.length; i++) {
            string memory version = filteredVersions[i];
            string memory contractJsonPath = string.concat("releases/", version, "/", contractName, ".json");

            if (!vm.exists(contractJsonPath)) continue;

            string memory contractJson = vm.readFile(contractJsonPath);
            if (bytes(contractJson).length == 0) continue;

            string memory addressPath = string.concat(".deployments.", environment, ".", vm.toString(chainId));

            try vm.parseJsonAddress(contractJson, addressPath) returns (address addr) {
                if (addr != address(0)) {
                    deployedAddress = addr;
                    deployedVersion = version;
                    break;
                }
            } catch {
                continue;
            }
        }

        string memory jsonPath = string.concat("releases/", currentVersion, "/", contractName, ".json");
        string memory workPath = string.concat(".deployments.", environment, ".", vm.toString(chainId));
        string memory json;
        try vm.readFile(jsonPath) returns (string memory content) {
            json = content;
        } catch {
            json = ""; // Empty if file doesn't exist
        }

        if (deployedAddress != address(0)) {
            // Parse versions
            VersionUtils.Version memory currentVersionParsed = currentVersion.parseVersion();
            VersionUtils.Version memory deployedVersionParsed = deployedVersion.parseVersion();

            // If trying to deploy older major version
            if (currentVersionParsed.major < deployedVersionParsed.major) {
                revert(
                    string.concat(
                        "Cannot deploy older version ", currentVersion, " when version ", deployedVersion, " exists"
                    )
                );
            }

            // If exact same version, use existing deployment
            if (
                currentVersionParsed.major == deployedVersionParsed.major
                    && currentVersionParsed.minor == deployedVersionParsed.minor
                    && currentVersionParsed.patch == deployedVersionParsed.patch
            ) {
                try vm.parseJson(json, workPath) returns (bytes memory existingDeployment) {
                    if (existingDeployment.length > 0) {
                        revert("Deployment already exists for this chain");
                    }
                } catch {
                    return address(0);
                }
            }

            // Deploy new if:
            // 1. Going from 0.x.x to 1.x.x or higher
            // 2. Major version jump is more than 1
            if (
                (deployedVersionParsed.major == 0 && currentVersionParsed.major > 0)
                    || currentVersionParsed.major > deployedVersionParsed.major + 1
            ) {
                return address(0);
            }

            return deployedAddress;
        }

        console2.log("No existing version found for", contractName, "in environment", environment);
        return address(0);
    }

    function _updateDeployments(string memory environment, uint256 chainId, address deployedAddress) internal {
        string memory contractName = vm.envString("CONTRACT");
        string memory version = vm.envString("VERSION");

        // 1. Update temp file
        _updateTempDeployment(environment, chainId, contractName, deployedAddress);

        // 2. Validate and prepare release
        _prepareReleaseJson(contractName, version);
    }

    function _updateTempDeployment(
        string memory environment,
        uint256 chainId,
        string memory contractName,
        address deployedAddress
    ) internal {
        // Create temp dirs
        string memory tempDir = "temp";
        string memory tempEnvDir = string.concat(tempDir, "/", environment);
        string memory tempChainDir = string.concat(tempEnvDir, "/", vm.toString(chainId));

        if (!vm.exists(tempDir)) vm.createDir(tempDir, true);
        if (!vm.exists(tempEnvDir)) vm.createDir(tempEnvDir, true);
        if (!vm.exists(tempChainDir)) vm.createDir(tempChainDir, true);

        // Write temp file
        string memory tempContractPath = string.concat(tempChainDir, "/", contractName, ".json");
        string memory tempJson =
            string(abi.encodePacked("{\"", contractName, "\": \"", vm.toString(deployedAddress), "\"}"));
        vm.writeFile(tempContractPath, tempJson);
    }

    function _prepareReleaseJson(string memory contractName, string memory version) internal returns (bool) {
        string memory releasePath = string.concat("releases/", version);
        string memory releaseJsonPath = string.concat(releasePath, "/", contractName, ".json");

        // Return if file already exists
        if (vm.exists(releaseJsonPath)) {
            return false;
        }

        // Create release directory if needed
        if (!vm.exists(releasePath)) {
            vm.createDir(releasePath, true);
        }

        // Create standard JSON with empty addresses
        string memory json = _getInitialJson(contractName, version);
        vm.writeFile(releaseJsonPath, json);
        console2.log("Created standard release file at: releases/", string.concat(version, "/", contractName, ".json"));
        return true;
    }

    function _getInitialJson(string memory contractName, string memory version) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                "{",
                '"name":"',
                contractName,
                '",',
                '"version":"',
                version,
                '",',
                '"deployments":',
                _initDeployments(),
                "}"
            )
        );
    }

    function _initDeployments() internal pure returns (string memory) {
        return string(abi.encodePacked("{", '"production":', _initChainIds(), ",", '"staging":', _initChainIds(), "}"));
    }

    function _initChainIds() internal pure returns (string memory) {
        return "{" '"1":"","11155111":"","42161":"","421614":"",' '"8453":"","84532":"","81457":"","168587773":"",'
        '"7887":"","161221135":"","98865":"","98864":""' "}";
    }
}
