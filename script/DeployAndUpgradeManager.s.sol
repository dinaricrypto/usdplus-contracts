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

        // Deploy implementation and proxy
        DeploymentConfig memory config = _deploy(contractName);

        // Update deployment files
        _updateDeploymentFiles(contractName, config, environment, chainId);

        console2.log("Deployment successful for contract:", contractName);
        console2.log("- Implementation:", config.implementation);
        console2.log("- Proxy:", config.proxy);
        console2.log("- Version:", config.version);
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
        (uint8 majorVersion,) = _parseVersion(config.version);
        string memory versionPath = string.concat(root, "/releases/v", vm.toString(majorVersion), "/");
        string memory fileName = string.concat(_toLowerSnakeCase(contractName), ".json");
        string memory jsonPath = string.concat(versionPath, fileName);

        // Create directory if it doesn't exist
        vm.createDir(versionPath, true);

        string memory json;
        try vm.readFile(jsonPath) returns (string memory content) {
            console2.log("Reading existing file:");
            console2.log(content);

            if (bytes(content).length == 0) {
                console2.log("Empty file, using default template");
                json = _getDefaultTemplate(contractName);
            } else {
                // Validate JSON structure
                if (bytes(content)[0] == "{" && bytes(content)[bytes(content).length - 1] == "}") {
                    json = content;
                } else {
                    console2.log("Invalid JSON structure, using default template");
                    json = _getDefaultTemplate(contractName);
                }
            }
        } catch {
            console2.log("File not found, using default template");
            json = _getDefaultTemplate(contractName);
        }

        // Update deployment path and version
        json = _updateJson(json, config, environment, chainId);

        console2.log("Writing updated JSON:");
        console2.log(json);

        vm.writeFile(jsonPath, json);
    }

    function _updateJson(string memory json, DeploymentConfig memory config, string memory environment, uint256 chainId)
        internal
        view
        returns (string memory)
    {
        if (bytes(json).length == 0) {
            json = _getDefaultTemplate(vm.envString("CONTRACT"));
        }

        string memory productionSection = "{}";
        string memory stagingSection = "{}";

        // Manual parsing to extract sections
        bytes memory jsonBytes = bytes(json);

        // Find production section
        uint256 prodStart = _findSectionStart(jsonBytes, "production");
        if (prodStart != type(uint256).max) {
            uint256 prodEnd = _findSectionEnd(jsonBytes, prodStart);
            if (prodEnd != type(uint256).max) {
                bytes memory prodContent = new bytes(prodEnd - prodStart);
                for (uint256 i = 0; i < prodEnd - prodStart; i++) {
                    prodContent[i] = jsonBytes[prodStart + i];
                }
                productionSection = string(prodContent);
            }
        }

        // Find staging section
        uint256 stagStart = _findSectionStart(jsonBytes, "staging");
        if (stagStart != type(uint256).max) {
            uint256 stagEnd = _findSectionEnd(jsonBytes, stagStart);
            if (stagEnd != type(uint256).max) {
                bytes memory stagContent = new bytes(stagEnd - stagStart);
                for (uint256 i = 0; i < stagEnd - stagStart; i++) {
                    stagContent[i] = jsonBytes[stagStart + i];
                }
                stagingSection = string(stagContent);
            }
        }

        console2.log("Extracted production section:", productionSection);
        console2.log("Extracted staging section:", stagingSection);

        if (keccak256(bytes(environment)) == keccak256(bytes("production"))) {
            productionSection = _buildNetworkSection(chainId, config.proxy, productionSection);
        } else {
            stagingSection = _buildNetworkSection(chainId, config.proxy, stagingSection);
        }

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
        for (uint256 i = 0; i < chainIds.length; i++) {
            // Look for pattern '"chainId": "address"'
            bytes memory pattern = bytes(string.concat('"', chainIds[i], '": "'));
            bytes memory sectionBytes = bytes(currentSection);

            uint256 start = _indexOf(sectionBytes, pattern);
            if (start != type(uint256).max) {
                start += pattern.length;
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

            section = string.concat(section, ' "', chainIds[i], '": "', addr, '"', i < chainIds.length - 1 ? "," : "");
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
        uint8 dots = 0;

        for (uint256 i = 0; i < versionBytes.length; i++) {
            if (versionBytes[i] == ".") dots++;
            else if (versionBytes[i] < "0" || versionBytes[i] > "9") revert InvalidVersionFormat();
        }

        if (dots != 2) revert InvalidVersionFormat();
    }

    function _parseVersion(string memory version) internal pure returns (uint8 major, uint8 minor) {
        bytes memory versionBytes = bytes(version);
        uint8 firstDot = 0;

        while (firstDot < versionBytes.length && versionBytes[firstDot] != ".") {
            major = major * 10 + uint8(uint8(versionBytes[firstDot]) - 48);
            firstDot++;
        }

        uint8 secondDot = uint8(firstDot + 1);
        while (secondDot < versionBytes.length && versionBytes[secondDot] != ".") {
            minor = minor * 10 + uint8(uint8(versionBytes[secondDot]) - 48);
            secondDot++;
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
