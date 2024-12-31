// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ControlledUpgradeable} from "../src/deployment/ControlledUpgradeable.sol";

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

    function run() external {
        // Get deployment parameters
        string memory contractName = vm.envString("CONTRACT");
        string memory environment = vm.envString("ENVIRONMENT");
        string memory version = vm.envString("VERSION");
        address owner = vm.envAddress("OWNER_ADDRESS");
        address upgrader = vm.envAddress("UPGRADER_ADDRESS");
        uint256 chainId = block.chainid;

        // Validate inputs
        _validateEnvironment(environment);
        _validateVersionFormat(version);

        // Deploy implementation and proxy
        DeploymentConfig memory config = _deploy(contractName, owner, upgrader, version);

        // Update deployment files
        _updateDeploymentFiles(contractName, config, environment, chainId);

        console2.log("Deployment successful for contract:", contractName);
        console2.log("- Implementation:", config.implementation);
        console2.log("- Proxy:", config.proxy);
        console2.log("- Version:", config.version);
    }

    function _deploy(string memory contractName, address owner, address upgrader, string memory version)
        internal
        returns (DeploymentConfig memory config)
    {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation
        address implementation = _deployImplementation(contractName);

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSignature("initialize(address,address,string)", owner, upgrader, version);

        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(implementation, initData);

        if (address(proxy) == address(0)) revert ProxyDeploymentFailed();

        vm.stopBroadcast();

        return DeploymentConfig({implementation: implementation, proxy: address(proxy), version: version});
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

        string memory versionPath = string.concat("/releases/v", vm.toString(majorVersion), "/");

        // Create directory if it doesn't exist
        if (!vm.exists(string.concat(root, versionPath))) {
            vm.createDir(string.concat(root, versionPath), true);
        }

        string memory fileName = string.concat(_toLowerSnakeCase(contractName), ".json");

        string memory jsonPath = string.concat(root, versionPath, fileName);

        // Create or update JSON
        string memory json = "{}";
        json = _updateJson(json, config, environment, chainId);

        // Write files
        vm.writeFile(jsonPath, json);
        vm.writeFile(string.concat(root, "/releases/previous-version/", fileName), json);
    }

    function _updateJson(string memory json, DeploymentConfig memory config, string memory environment, uint256 chainId)
        internal
        returns (string memory)
    {
        json = vm.serializeString(json, "version", config.version);
        json = vm.serializeAddress(json, "implementation", config.implementation);
        json = vm.serializeAddress(
            json, string.concat("deployments.", environment, ".", vm.toString(chainId)), config.proxy
        );
        return json;
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

        // Parse major version
        while (firstDot < versionBytes.length && versionBytes[firstDot] != ".") {
            major = major * 10 + uint8(uint8(versionBytes[firstDot]) - 48); // 48 is ASCII for '0'
            firstDot++;
        }

        // Parse minor version
        uint8 secondDot = uint8(firstDot + 1);
        while (secondDot < versionBytes.length && versionBytes[secondDot] != ".") {
            minor = minor * 10 + uint8(uint8(versionBytes[secondDot]) - 48);
            secondDot++;
        }
    }

    function _toLowerSnakeCase(string memory input) internal pure returns (string memory) {
        bytes memory inputBytes = bytes(input);
        bytes memory result = new bytes(inputBytes.length * 2);

        uint256 j = 0;
        for (uint256 i = 0; i < inputBytes.length; i++) {
            bytes1 char = inputBytes[i];

            if (char >= 0x41 && char <= 0x5A) {
                if (i > 0) {
                    result[j] = 0x5F;
                    j++;
                }
                result[j] = bytes1(uint8(char) + 32);
            } else {
                result[j] = char;
            }
            j++;
        }

        bytes memory finalResult = new bytes(j);
        for (uint256 i = 0; i < j; i++) {
            finalResult[i] = result[i];
        }

        return string(finalResult);
    }
}
