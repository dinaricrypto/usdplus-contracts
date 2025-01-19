// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ControlledUpgradeable} from "../src/deployment/ControlledUpgradeable.sol";
import {DeployHelper} from "./DeployHelper.sol";
import {JsonHandler} from "./JsonHandler.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {InitializeParams} from "./InitializeParams.sol";

contract DeployAndUpgradeManager is Script {
    using stdJson for string;

    error InvalidEnvironment(string environment);
    error InvalidVersionFormat();
    error ProxyDeploymentFailed();

    struct DeploymentConfig {
        address implementation;
        address proxy;
        string version;
    }

    DeployHelper public helper;

    constructor() {
        helper = new DeployHelper();
    }

    function run() external {
        // Get deployment parameters
        string memory contractName = vm.envString("CONTRACT");
        string memory environment = vm.envString("ENVIRONMENT");
        string memory version = vm.envString("VERSION");
        uint256 chainId = block.chainid;

        // Validate inputs
        _validateEnvironment(environment);
        _validateVersionFormat(version);

        // Check for existing proxy and version
        (uint8 targetMajor,) = _parseVersion(version);
        (bool shouldUpgrade, address proxyAddress, string memory currentVersion) =
            _checkForUpgrade(contractName, environment, chainId, targetMajor);

        // Deploy implementation and proxy
        DeploymentConfig memory config;

        if (shouldUpgrade) {
            // Check if versions match
            if (keccak256(bytes(version)) == keccak256(bytes(currentVersion))) {
                console2.log("\nContract already at requested version:", version);
                console2.log("- Contract:", contractName);
                console2.log("- Environment:", environment);
                console2.log("- Chain ID:", chainId);
                console2.log("- Proxy:", proxyAddress);
                console2.log("No upgrade needed");
                return;
            }

            console2.log("\nUpgrading contract:");
            console2.log("- Contract:", contractName);
            console2.log("- Environment:", environment);
            console2.log("- Chain ID:", chainId);
            console2.log("- Proxy:", proxyAddress);
            console2.log(string.concat("- Version: ", currentVersion, " -> ", version));
            config = _upgrade(contractName, proxyAddress, version, environment);
        } else {
            console2.log("\nDeploying new contract:");
            console2.log("- Contract:", contractName);
            console2.log("- Environment:", environment);
            console2.log("- Chain ID:", chainId);
            if (bytes(currentVersion).length > 0) {
                console2.log(string.concat("- Version: ", currentVersion, " -> ", version, " (major version change)"));
            } else {
                console2.log(string.concat("- Version: Initial deployment ", version));
            }
            config = _deploy(contractName, version, environment);
        }

        // Update deployment files
        _updateDeploymentFiles(contractName, config, environment, chainId);

        console2.log("\nDeployment successful:");
        console2.log("- Contract:", contractName);
        console2.log("- Implementation:", config.implementation);
        console2.log("- Proxy:", config.proxy);
        if (shouldUpgrade) {
            console2.log(string.concat("- Version: ", currentVersion, " -> ", version));
        } else {
            console2.log(string.concat("- Version: ", version));
        }
    }

    function _getDeploymentPath(string memory contractName, uint8 targetMajorVersion)
        internal
        view
        returns (string memory)
    {
        string memory root = vm.projectRoot();
        string memory versionPath = string.concat(root, "/releases/v", vm.toString(targetMajorVersion), "/");
        return string.concat(versionPath, _toLowerSnakeCase(contractName), ".json");
    }

    function _getProxyFromSection(string memory currentSection, uint256 chainId)
        internal
        pure
        returns (bool found, address proxyAddr)
    {
        (bool exists, string memory addr) = JsonHandler._findAddress(bytes(currentSection), vm.toString(chainId));
        if (exists && bytes(addr).length > 0) {
            return (true, vm.parseAddress(addr));
        }
        return (false, address(0));
    }

    function _checkForUpgrade(
        string memory contractName,
        string memory environment,
        uint256 chainId,
        uint8 targetMajorVersion
    ) internal view returns (bool shouldUpgrade, address proxyAddress, string memory currentVersion) {
        // Get deployment file path
        string memory jsonPath = _getDeploymentPath(contractName, targetMajorVersion);

        console2.log("\nChecking for upgrades in file:", jsonPath);
        console2.log("Environment:", environment);
        console2.log("Chain ID:", chainId);

        // Read deployment file
        string memory content = JsonHandler._readDeploymentFile(jsonPath);
        if (bytes(content).length == 0) {
            console2.log("No existing deployment file found");
            return (false, address(0), "");
        }

        // Get current version
        bytes memory versionBytes = content.parseRaw(".version");
        currentVersion = versionBytes.length > 0 ? abi.decode(versionBytes, (string)) : "";

        // Get network section
        JsonHandler.NetworkSection memory sections = JsonHandler._extractNetworkSections(content);
        string memory currentSection =
            keccak256(bytes(environment)) == keccak256(bytes("production")) ? sections.production : sections.staging;

        // Find proxy address
        (bool found, address proxy) = _getProxyFromSection(currentSection, chainId);

        if (found) {
            console2.log("Found existing proxy:", proxy);
            return (true, proxy, currentVersion);
        }

        console2.log("No existing proxy found for environment", environment, "and chain:", chainId);
        return (false, address(0), currentVersion);
    }

    function _deploy(string memory contractName, string memory version, string memory environment)
        internal
        returns (DeploymentConfig memory config)
    {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation
        address implementation = _deployImplementation(contractName);

        // Get initialization parameters from helper
        bytes memory params = helper.getInitializeParams(contractName, version, environment);

        // Get initialization data using helper
        bytes memory initData = helper.getInitializeCalldata(contractName, params);

        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(implementation, initData);

        if (address(proxy) == address(0)) revert ProxyDeploymentFailed();

        vm.stopBroadcast();

        return DeploymentConfig({implementation: implementation, proxy: address(proxy), version: version});
    }

    function _upgrade(
        string memory contractName,
        address proxyAddress,
        string memory version,
        string memory environment
    ) internal returns (DeploymentConfig memory config) {
        // Get initialization parameters from helper
        bytes memory params = helper.getInitializeParams(contractName, version, environment);

        // Get reinitialization data
        bytes memory initData = helper.getReinitializeCalldata(contractName, params);

        // deploy new implementation
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address newImplementation = _deployImplementation(contractName);
        vm.stopBroadcast();

        ControlledUpgradeable proxy = ControlledUpgradeable(proxyAddress);

        uint256 upgraderPrivateKey = vm.envUint("DEPLOYER_KEY");
        vm.startBroadcast(upgraderPrivateKey);
        proxy.upgradeToAndCall(newImplementation, initData);
        vm.stopBroadcast();

        return DeploymentConfig({implementation: newImplementation, proxy: address(proxy), version: version});
    }

    function _deployImplementation(string memory contractName) internal returns (address) {
        bytes memory bytecode =
            abi.encodePacked(vm.getCode(string.concat("out/", contractName, ".sol/", contractName, ".json")));
        address implementation;
        assembly {
            implementation := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        return implementation;
    }

    function _updateDeploymentFiles(
        string memory contractName,
        DeploymentConfig memory config,
        string memory environment,
        uint256 chainId
    ) internal {
        string memory root = vm.projectRoot();

        // Parse the target version from config
        (uint8 majorVersion,) = _parseVersion(config.version);

        // Create the version path using the major version
        string memory versionPath = string.concat(root, "/releases/v", vm.toString(majorVersion), "/");
        string memory fileName = string.concat(_toLowerSnakeCase(contractName), ".json");
        string memory jsonPath = string.concat(versionPath, fileName);

        // Create directory if it doesn't exist
        vm.createDir(versionPath, true);

        // Read existing file or use default template
        string memory content = JsonHandler._readDeploymentFile(jsonPath);
        string memory json = bytes(content).length == 0 ? JsonHandler._getDefaultTemplate(contractName) : content;

        // Build new network section
        JsonHandler.NetworkSection memory sections = JsonHandler._extractNetworkSections(json);
        string memory currentSection =
            keccak256(bytes(environment)) == keccak256(bytes("production")) ? sections.production : sections.staging;

        string memory networkSection = JsonHandler._buildNetworkSection(chainId, config.proxy, currentSection);

        // Update JSON with new section
        json = JsonHandler._updateJson(json, contractName, config.version, environment, networkSection);

        console2.log("Writing updated JSON:");
        console2.log(json);

        vm.writeFile(jsonPath, json);
    }

    function _parseVersion(string memory version) internal pure returns (uint8 major, uint8 minor) {
        bytes memory versionBytes = bytes(version);
        uint256 pos = 0;
        major = 0;
        minor = 0;
        uint8 patch = 0;

        // Parse major version
        while (pos < versionBytes.length && versionBytes[pos] != ".") {
            major = major * 10 + uint8(uint8(versionBytes[pos]) - 48);
            pos++;
        }
        if (pos >= versionBytes.length) revert InvalidVersionFormat();

        // Move past first dot
        pos++;

        // Parse minor version
        while (pos < versionBytes.length && versionBytes[pos] != ".") {
            minor = minor * 10 + uint8(uint8(versionBytes[pos]) - 48);
            pos++;
        }
        if (pos >= versionBytes.length) revert InvalidVersionFormat();

        // Move past second dot
        pos++;

        // Parse patch version
        while (pos < versionBytes.length && versionBytes[pos] != ".") {
            patch = patch * 10 + uint8(uint8(versionBytes[pos]) - 48);
            pos++;
        }

        // Ensure we've reached the end and found all three numbers
        if (pos != versionBytes.length) revert InvalidVersionFormat();
    }

    function _validateEnvironment(string memory environment) internal pure {
        if (
            keccak256(bytes(environment)) != keccak256(bytes("production"))
                && keccak256(bytes(environment)) != keccak256(bytes("staging"))
        ) {
            revert InvalidEnvironment(environment);
        }
    }

    function _validateVersionFormat(string memory version) internal pure {
        bytes memory versionBytes = bytes(version);
        uint256 pos = 0;
        bool hasDigit = false;
        uint8 dots = 0;

        // Check major version
        while (pos < versionBytes.length && versionBytes[pos] != ".") {
            if (versionBytes[pos] < "0" || versionBytes[pos] > "9") revert InvalidVersionFormat();
            hasDigit = true;
            pos++;
        }
        if (!hasDigit || pos >= versionBytes.length) revert InvalidVersionFormat();
        dots++;

        // Check minor version
        pos++; // Skip dot
        hasDigit = false;
        while (pos < versionBytes.length && versionBytes[pos] != ".") {
            if (versionBytes[pos] < "0" || versionBytes[pos] > "9") revert InvalidVersionFormat();
            hasDigit = true;
            pos++;
        }
        if (!hasDigit || pos >= versionBytes.length) revert InvalidVersionFormat();
        dots++;

        // Check patch version
        pos++; // Skip dot
        hasDigit = false;
        while (pos < versionBytes.length) {
            if (versionBytes[pos] == ".") revert InvalidVersionFormat();
            if (versionBytes[pos] < "0" || versionBytes[pos] > "9") revert InvalidVersionFormat();
            hasDigit = true;
            pos++;
        }
        if (!hasDigit || dots != 2) revert InvalidVersionFormat();
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
