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

        string memory json;
        try vm.readFile(jsonPath) returns (string memory content) {
            json = bytes(content).length == 0 ? _getDefaultTemplate(contractName) : content;
        } catch {
            json = _getDefaultTemplate(contractName);
        }

        // Update deployment path and version
        json = _updateJson(json, config, environment, chainId);
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

        // Get current deployments structure to preserve values
        bytes memory currentDeployments = stdJson.parseRaw(json, ".deployments");

        // Create new JSON maintaining structure
        string memory newJson = string(
            abi.encodePacked(
                "{",
                '"name":"',
                vm.envString("CONTRACT"),
                '",',
                '"version":"',
                config.version,
                '",',
                '"deployments":{',
                '"production":{',
                keccak256(bytes(environment)) == keccak256(bytes("production"))
                    ? _buildNetworkSection(chainId, config.proxy)
                    : _buildNetworkSection(0, address(0)),
                "},",
                '"staging":{',
                keccak256(bytes(environment)) == keccak256(bytes("staging"))
                    ? _buildNetworkSection(chainId, config.proxy)
                    : _buildNetworkSection(0, address(0)),
                "}",
                "},",
                '"abi":[]',
                "}"
            )
        );

        return newJson;
    }

    function _buildNetworkSection(uint256 targetChainId, address proxyAddress) internal pure returns (string memory) {
        string[10] memory chainIds =
            ["1", "11155111", "42161", "421614", "8453", "84532", "81457", "168587773", "7887", "161221135"];

        string memory section = "";
        for (uint256 i = 0; i < chainIds.length; i++) {
            // Convert string chainId to uint for comparison
            string memory jsonStr = string.concat('{"chainId":', chainIds[i], "}");
            uint256 currentChainId = vm.parseJsonUint(jsonStr, ".chainId");

            section = string.concat(
                section,
                '"',
                chainIds[i],
                '":"',
                currentChainId == targetChainId ? vm.toString(proxyAddress) : "",
                '"',
                i < chainIds.length - 1 ? "," : "" // Add comma if not last item
            );
        }

        return section;
    }

    function _getDefaultTemplate(string memory contractName) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                "{",
                '"name":"',
                contractName,
                '",',
                '"version":"",',
                '"deployments":{',
                '"production":{',
                '"1":"","11155111":"","42161":"","421614":"",',
                '"8453":"","84532":"","81457":"","168587773":"",',
                '"7887":"","161221135":""',
                "},",
                '"staging":{',
                '"1":"","11155111":"","42161":"","421614":"",',
                '"8453":"","84532":"","81457":"","168587773":"",',
                '"7887":"","161221135":""',
                "}",
                "},",
                '"abi":[]',
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
