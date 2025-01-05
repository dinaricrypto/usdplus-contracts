// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ControlledUpgradeable} from "../src/deployment/ControlledUpgradeable.sol";
import {DeployHelper} from "./DeployHelper.sol";

contract DeployAndUpgradeManager is Script {
    using stdJson for string;

    error InvalidEnvironment(string environment);
    error InvalidChainId(uint256 chainId);
    error ContractNotFound(string contractName);
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

        // Check for exisitng proxy
        (uint8 targetMajor,) = _parseVersion(version);
        (bool shouldUpgrade, address proxyAddress) = _checkForUpgrade(contractName, environment, chainId, targetMajor);

        // Deploy implementation and proxy
        DeploymentConfig memory config;

        if (shouldUpgrade) {
            console2.log("Found existing proxy at:", proxyAddress, "for major version", targetMajor);
            console2.log("Upgrading to version:", version);
            // config = _upgrade(contractName, proxyAddress);
        } else {
            console2.log("Major version change detected or no existing proxy found");
            console2.log("Deploying new implementation and proxy for version", version);
            config = _deploy(contractName);
        }

        // Update deployment files
        _updateDeploymentFiles(contractName, config, environment, chainId);

        console2.log("Deployment successful for contract:", contractName);
        console2.log("- Implementation:", config.implementation);
        console2.log("- Proxy:", config.proxy);
        console2.log("- Version:", config.version);
    }

    function _checkForUpgrade(
        string memory contractName,
        string memory environment,
        uint256 chainId,
        uint8 targetMajorVersion
    ) internal view returns (bool shouldUpgrade, address proxyAddress) {
        string memory root = vm.projectRoot();
        string memory versionPath = string.concat(root, "/releases/v", vm.toString(targetMajorVersion), "/");
        string memory fileName = string.concat(_toLowerSnakeCase(contractName), ".json");
        string memory jsonPath = string.concat(versionPath, fileName);

        console2.log("\nChecking for upgrades in file:", jsonPath);
        console2.log("Environment:", environment);
        console2.log("Chain ID:", chainId);

        // Read deployment file
        string memory content = vm.readFile(jsonPath);
        if (bytes(content).length == 0) {
            console2.log("No existing deployment file found");
            return (false, address(0));
        }

        // Find environment section using the same method as _updateJson
        bytes memory jsonBytes = bytes(content);
        uint256 sectionStart = _findSectionStart(jsonBytes, environment);
        if (sectionStart == type(uint256).max) {
            console2.log("No section found for environment:", environment);
            return (false, address(0));
        }

        uint256 sectionEnd = _findSectionEnd(jsonBytes, sectionStart);
        if (sectionEnd == type(uint256).max) {
            console2.log("Invalid section format for environment:", environment);
            return (false, address(0));
        }

        // Extract section content
        bytes memory sectionContent = new bytes(sectionEnd - sectionStart);
        for (uint256 i = 0; i < sectionEnd - sectionStart; i++) {
            sectionContent[i] = jsonBytes[sectionStart + i];
        }
        string memory sectionStr = string(sectionContent);
        console2.log("Found section content:", sectionStr);

        // Search for chain address
        bytes memory pattern = bytes(string.concat('"', vm.toString(chainId), '": "'));
        uint256 start = _indexOf(bytes(sectionStr), pattern);

        if (start != type(uint256).max) {
            start += pattern.length;
            bytes memory sectionBytes = bytes(sectionStr);
            uint256 end = start;

            while (end < sectionBytes.length && sectionBytes[end] != '"') {
                end++;
            }

            if (end > start) {
                bytes memory addrBytes = new bytes(end - start);
                for (uint256 i = 0; i < end - start; i++) {
                    addrBytes[i] = sectionBytes[start + i];
                }
                string memory addr = string(addrBytes);
                if (bytes(addr).length > 0) {
                    console2.log("Found existing proxy:", addr);
                    return (true, vm.parseAddress(addr));
                }
            }
        }

        console2.log("No existing proxy found for environment", environment, "and chain:", chainId);
        return (false, address(0));
    }

    function _deploy(string memory contractName) internal returns (DeploymentConfig memory config) {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation
        address implementation = _deployImplementation(contractName);

        // Get initialization parameters from helper
        DeployHelper.InitializeParams memory params = helper.getInitializeParams();

        // Get initialization data using helper
        bytes memory initData = helper.getInitializeCalldata(params);

        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(implementation, initData);

        if (address(proxy) == address(0)) revert ProxyDeploymentFailed();

        vm.stopBroadcast();

        return DeploymentConfig({implementation: implementation, proxy: address(proxy), version: params.version});
    }

    // function _upgrade(string memory contractName, address proxyAddress) internal returns (DeploymentConfig memory config) {}

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

        // Create the version path using the major version from the VERSION
        string memory versionPath = string.concat(root, "/releases/v", vm.toString(majorVersion), "/");
        string memory fileName = string.concat(_toLowerSnakeCase(contractName), ".json");
        string memory jsonPath = string.concat(versionPath, fileName);

        // Create directory if it doesn't exist
        vm.createDir(versionPath, true);

        // Read existing file or use default template
        string memory content;
        try vm.readFile(jsonPath) returns (string memory fileContent) {
            content = fileContent;
            console2.log("Reading existing file:");
            console2.log(content);
        } catch {
            content = "";
            console2.log("No existing file found, using default template");
        }

        string memory json = bytes(content).length == 0 ? _getDefaultTemplate(contractName) : content;

        // Update deployment path and version
        json = _updateJson(json, config, environment, chainId);

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

    // Helper function to build the deployment path
    function _getDeploymentPath(string memory root, string memory contractName, uint8 majorVersion)
        internal
        pure
        returns (string memory)
    {
        return
            string.concat(root, "/releases/v", vm.toString(majorVersion), "/", _toLowerSnakeCase(contractName), ".json");
    }

    function _updateJson(string memory json, DeploymentConfig memory config, string memory environment, uint256 chainId)
        internal
        view
        returns (string memory)
    {
        if (bytes(json).length == 0) {
            json = _getDefaultTemplate(vm.envString("CONTRACT"));
        }

        // Initialize sections with default empty network sections
        string memory productionSection = string(abi.encodePacked("{", _getEmptyNetworkSection(), "}"));
        string memory stagingSection = string(abi.encodePacked("{", _getEmptyNetworkSection(), "}"));

        // Manual parsing to extract sections
        bytes memory jsonBytes = bytes(json);

        // Find and extract production section if it exists
        uint256 prodStart = _findSectionStart(jsonBytes, "production");
        if (prodStart != type(uint256).max) {
            uint256 prodEnd = _findSectionEnd(jsonBytes, prodStart);
            if (prodEnd != type(uint256).max) {
                bytes memory prodContent = new bytes(prodEnd - prodStart);
                for (uint256 i = 0; i < prodEnd - prodStart; i++) {
                    prodContent[i] = jsonBytes[prodStart + i];
                }
                string memory prodSection = string(prodContent);
                if (bytes(prodSection).length > 0 && keccak256(bytes(prodSection)) != keccak256(bytes("{}"))) {
                    productionSection = prodSection;
                }
            }
        }

        // Find and extract staging section if it exists
        uint256 stagStart = _findSectionStart(jsonBytes, "staging");
        if (stagStart != type(uint256).max) {
            uint256 stagEnd = _findSectionEnd(jsonBytes, stagStart);
            if (stagEnd != type(uint256).max) {
                bytes memory stagContent = new bytes(stagEnd - stagStart);
                for (uint256 i = 0; i < stagEnd - stagStart; i++) {
                    stagContent[i] = jsonBytes[stagStart + i];
                }
                string memory stagSection = string(stagContent);
                if (bytes(stagSection).length > 0 && keccak256(bytes(stagSection)) != keccak256(bytes("{}"))) {
                    stagingSection = stagSection;
                }
            }
        }

        // Update the appropriate section based on environment
        if (keccak256(bytes(environment)) == keccak256(bytes("production"))) {
            productionSection = _buildNetworkSection(chainId, config.proxy, productionSection);
        } else {
            stagingSection = _buildNetworkSection(chainId, config.proxy, stagingSection);
        }

        // Construct the final JSON with both sections properly formatted
        return string(
            abi.encodePacked(
                "{",
                '"name":"',
                vm.envString("CONTRACT"),
                '",',
                '"version":"',
                config.version,
                '",',
                '"deployments":{',
                '"production":',
                productionSection,
                ",",
                '"staging":',
                stagingSection,
                "},",
                '"abi":[]',
                "}"
            )
        );
    }

    function _findSectionStart(bytes memory json, string memory section) internal pure returns (uint256) {
        // Look for the pattern '"section": {'
        bytes memory pattern = bytes(string.concat('"', section, '": {'));
        uint256 pos = _indexOf(json, pattern);
        if (pos != type(uint256).max) {
            return pos + pattern.length - 1; // Return position after the opening brace
        }
        return type(uint256).max;
    }

    function _findSectionEnd(bytes memory json, uint256 start) internal pure returns (uint256) {
        if (start == type(uint256).max) return type(uint256).max;

        // Find matching closing brace considering nesting
        uint256 depth = 1;
        for (uint256 i = start + 1; i < json.length; i++) {
            if (json[i] == bytes1("{")) {
                depth++;
            } else if (json[i] == bytes1("}")) {
                depth--;
                if (depth == 0) return i + 1; // Include the closing brace
            }
        }
        return type(uint256).max;
    }

    function _buildNetworkSection(uint256 targetChainId, address proxyAddress, string memory currentSection)
        internal
        view
        returns (string memory)
    {
        string[10] memory chainIds =
            ["1", "11155111", "42161", "421614", "8453", "84532", "81457", "168587773", "7887", "161221135"];

        console2.log("\nBuilding network section:");
        console2.log("Target chainId:", targetChainId);
        console2.log("Current section:", currentSection);

        // Store existing addresses
        string[10] memory existingAddresses;

        // Parse each address in the current section
        bytes memory sectionBytes = bytes(currentSection);
        for (uint256 i = 0; i < chainIds.length; i++) {
            // Look for pattern '"chainId":"address"' or '"chainId": "address"'
            bytes memory pattern1 = bytes(string.concat('"', chainIds[i], '":"'));
            bytes memory pattern2 = bytes(string.concat('"', chainIds[i], '": "'));

            uint256 start = _indexOf(sectionBytes, pattern1);
            if (start == type(uint256).max) {
                start = _indexOf(sectionBytes, pattern2);
                if (start != type(uint256).max) {
                    start += pattern2.length;
                }
            } else {
                start += pattern1.length;
            }

            if (start != type(uint256).max) {
                uint256 end = start;
                while (end < sectionBytes.length && sectionBytes[end] != '"') {
                    end++;
                }

                if (end > start) {
                    bytes memory addrBytes = new bytes(end - start);
                    for (uint256 j = 0; j < end - start; j++) {
                        addrBytes[j] = sectionBytes[start + j];
                    }
                    existingAddresses[i] = string(addrBytes);
                    console2.log("Found existing address for chain", chainIds[i], ":", string(addrBytes));
                }
            }
        }

        // Build new section
        string memory section = "{";
        for (uint256 i = 0; i < chainIds.length; i++) {
            uint256 currentChainId;
            bytes memory chainIdBytes = bytes(chainIds[i]);
            for (uint256 j = 0; j < chainIdBytes.length; j++) {
                currentChainId = currentChainId * 10 + (uint8(chainIdBytes[j]) - 48);
            }

            string memory addr;
            if (currentChainId == targetChainId) {
                addr = vm.toString(proxyAddress);
                console2.log("Setting new address for chain", chainIds[i], ":", addr);
            } else if (bytes(existingAddresses[i]).length > 0) {
                addr = existingAddresses[i];
                console2.log("Keeping existing address for chain", chainIds[i], ":", addr);
            } else {
                addr = "";
            }

            section = string.concat(section, '"', chainIds[i], '":"', addr, '"', i < chainIds.length - 1 ? "," : "");
        }
        section = string.concat(section, "}");

        console2.log("Built section:", section);
        return section;
    }

    function _indexOf(bytes memory haystack, bytes memory needle) internal pure returns (uint256) {
        if (needle.length == 0 || needle.length > haystack.length) {
            return type(uint256).max;
        }

        for (uint256 i = 0; i < haystack.length - needle.length + 1; i++) {
            bool found = true;
            for (uint256 j = 0; j < needle.length; j++) {
                if (haystack[i + j] != needle[j]) {
                    found = false;
                    break;
                }
            }
            if (found) {
                return i;
            }
        }
        return type(uint256).max;
    }

    function _getEmptyNetworkSection() internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                '"1":"",',
                '"11155111":"",',
                '"42161":"",',
                '"421614":"",',
                '"8453":"",',
                '"84532":"",',
                '"81457":"",',
                '"168587773":"",',
                '"7887":"",',
                '"161221135":""'
            )
        );
    }

    function _getDefaultTemplate(string memory contractName) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                "{\n",
                '  "name": "',
                contractName,
                '",\n',
                '  "version": "",\n',
                '  "deployments": {\n',
                '      "production": {\n',
                "          ",
                _getEmptyNetworkSection(),
                "\n      },\n",
                '      "staging": {\n',
                "          ",
                _getEmptyNetworkSection(),
                "\n      }\n",
                "  },\n",
                '  "abi": []\n',
                "}"
            )
        );
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
